import test from 'node:test';
import assert from 'node:assert/strict';
import { restaurantIntent, brandMatches, scopedFoodSearch, validateDishes } from '../supabase/functions/_shared/restaurant-context.ts';
import { guidedFood } from '../supabase/functions/_shared/guided-food.ts';

const request = (extra: any = {}) => ({schemaVersion:2,text:'Chicken bowl from Chipotle',draftId:'draft',draftRevision:1,...extra});
const estimate = {servingDesc:'1 serving',grams:100,calories:150,proteinG:20,carbsG:2,fatG:5,fiberG:0};
const component = (name='Chicken',state='included') => ({id:name,name,state,quantity:1,fromDescription:true,uncertain:false});
const dish = (ingredients: any[] = [component()]) => ({id:'bowl',name:'Chicken bowl',customizable:true,ingredients});

test('Chipotle ambiguity, seasoning, explicit venue and rejection are distinct', () => {
  assert.equal(restaurantIntent('chipotle chicken',null,null).clarification?.choices.length,2);
  assert.equal(restaurantIntent('chicken with chipotle sauce',null,null).restaurant,null);
  assert.equal(restaurantIntent('chicken bowl from Chipotle',null,null).restaurant?.name,'Chipotle');
  assert.equal(restaurantIntent('chipotle chicken',null,'ingredient').clarification,null);
  assert.equal(restaurantIntent('bowl from Chipotle',null,'none').restaurant,null);
  assert.equal(restaurantIntent('chipotle chicken from Texas Roadhouse',null,null).restaurant?.name,'Texas Roadhouse');
});
test('explicit conflicts require a choice and confirmation resolves that conflict', () => {
  const manual={name:'Chipotle',origin:'manual' as const};
  assert.equal(restaurantIntent('steak from Texas Roadhouse',manual,null).clarification?.choices.length,2);
  assert.equal(restaurantIntent('steak from Texas Roadhouse',{...manual,origin:'confirmed'},null).restaurant?.name,'Chipotle');
  assert.equal(restaurantIntent('from Chipotle and Texas Roadhouse',null,null).clarification?.choices.length,0);
  assert.equal(brandMatches('Chipotle Mexican Grill','Chipotle'),true);
  assert.equal(brandMatches('Not Chipotle','Chipotle'),false);
});
test('clarification happens before model or food calls', async () => {
  const fail=async()=>{throw Error('must not run')};
  const r=await guidedFood(request({text:'chipotle chicken'}),{food:fail,model:fail});
  assert.equal(r.status,'needs_restaurant'); assert.deepEqual(r.items,[]);
});
test('checklist only prefills stated chicken and keeps suggestions unspecified', async () => {
  const r=await guidedFood(request(),{food:async()=>{throw Error('no lookup yet')},model:async()=>({dishes:[{name:'Chicken bowl',customizable:true,ingredients:[{name:'Chicken',evidence:'Chicken',quantity:1,state:'included',uncertain:false}]}]})});
  assert.equal(r.status,'needs_ingredients');
  assert.deepEqual(r.dishes![0].ingredients.filter(x=>x.state==='included').map(x=>x.name),['Chicken']);
  assert.equal(r.dishes![0].ingredients.find(x=>x.name==='Cheese')?.state,'unspecified');
});
test('explicit negatives and quantities survive extraction', async () => {
  const r=await guidedFood(request({text:'double chicken, brown rice, no cheese in my bowl from Chipotle'}),{food:async()=>{throw Error('no lookup')},model:async()=>({dishes:[{name:'Chicken bowl',customizable:true,ingredients:[
    {name:'Chicken',evidence:'double chicken',quantity:2,state:'included',uncertain:false},
    {name:'Brown rice',evidence:'brown rice',quantity:1,state:'included',uncertain:false},
    {name:'Cheese',evidence:'no cheese',quantity:1,state:'excluded',uncertain:false}]}]})});
  assert.equal(r.dishes![0].ingredients.find(x=>x.name==='Chicken')?.quantity,2);
  assert.equal(r.dishes![0].ingredients.find(x=>x.name==='Cheese')?.state,'excluded');
});
test('invented ingredients without named transcript evidence are rejected', () => {
  assert.throws(()=>validateDishes([{name:'Bowl',customizable:true,ingredients:[{name:'Cheese',evidence:'bowl',quantity:1,state:'included'}]}],'chicken bowl'));
});
test('restaurant search retains correct aliases and labels alternatives with independent pagination', async () => {
  const calls: any[]=[];
  const r=await scopedFoodSearch(async p=>{calls.push(p);return {foods:{total_results:'70',food:p.search_expression.startsWith('Chipotle ')?[{food_id:'1',food_name:'Chicken',brand_name:'Chipotle Mexican Grill'}]:[{food_id:'2',food_name:'Chicken',brand_name:'Another chain'},{food_id:'3',food_name:'Chicken'}]}}},'chicken','Chipotle',2,25);
  assert.equal(r.rows[0].matchKind,'restaurant'); assert.equal(r.rows[1].matchKind,'generic');
  assert.equal(calls.length,2); assert.ok(calls.every(x=>x.page_number==='2')); assert.equal(r.total,70);
});
test('ready resolution validates food and serving IDs and applies quantity once', async () => {
  let n=0;
  const r=await guidedFood(request({compositionConfirmed:true,dishes:[dish([{...component(),quantity:2},component('Cheese','excluded')])]}),{
    model:async()=>++n===1?{foodId:'10',servingId:null,estimate}:{servingId:'serving-2'},
    food:async p=>p.method==='foods.search'?{foods:{food:[{food_id:'10',food_name:'Chicken',brand_name:'Chipotle Mexican Grill'}],total_results:1}}:{food:{food_id:'10',food_name:'Chicken',brand_name:'Chipotle Mexican Grill',servings:{serving:[
      {serving_id:'serving-1',serving_description:'100 g',metric_serving_amount:'100',calories:'100',protein:'10',carbohydrate:'1',fat:'2'},
      {serving_id:'serving-2',serving_description:'1 portion',metric_serving_amount:'120',calories:'180',protein:'30',carbohydrate:'2',fat:'6'}]}}}
  });
  assert.equal(r.status,'ready'); assert.equal(r.items.length,1); assert.equal(r.items[0].selectedServingId,'serving-2');
  assert.equal(r.items[0].calories,180); assert.equal(r.items[0].quantity,2); assert.equal(r.items[0].matchKind,'restaurant');
});
test('forged selection IDs and provider failures cannot become verified food', async () => {
  const body=request({compositionConfirmed:true,dishes:[dish()]});
  await assert.rejects(guidedFood(body,{model:async()=>({foodId:'forged',estimate}),food:async()=>({foods:{food:[]}})}));
  await assert.rejects(guidedFood(body,{model:async()=>({foodId:null,estimate}),food:async()=>{throw Error('provider unavailable')}}));
});
test('unknown variants produce labeled estimates and never claim a venue match', async () => {
  const r=await guidedFood(request({compositionConfirmed:true,dishes:[dish([{...component('Rice'),uncertain:true}])]}),{food:async()=>{throw Error('uncertain variants cannot be precise matches')},model:async()=>({foodId:null,servingId:null,estimate})});
  assert.equal(r.items[0].source,'estimated'); assert.equal(r.items[0].brand,null); assert.equal(r.items[0].matchKind,'estimated');
});
test('empty composition, excessive portions and malformed drafts are rejected', async () => {
  const deps={food:async()=>({}),model:async()=>({})};
  await assert.rejects(guidedFood(request({compositionConfirmed:true,dishes:[dish([component('Cheese','excluded')])]}),deps));
  await assert.rejects(guidedFood(request({draftRevision:-1}),deps));
  assert.throws(()=>validateDishes([dish([{...component(),quantity:100}])]));
});

test('weight descriptions are not serving multipliers and exclusions tolerate zero from extraction', () => {
  const rows = validateDishes([{name:'Dinner',customizable:false,ingredients:[{name:'sirloin steak',state:'included',quantity:6,evidence:'six ounce sirloin steak',uncertain:false},{name:'cheese',state:'excluded',quantity:0,evidence:'no cheese',uncertain:false}]}], 'A six ounce sirloin steak and no cheese');
  assert.equal(rows[0].ingredients[0].quantity,1);
  assert.match(rows[0].ingredients[0].name,/6 ounce/);
  assert.equal(rows[0].ingredients[1].state,'excluded');
  assert.equal(rows[0].ingredients[1].quantity,1);
});

test('explicit chicken in the dish name survives model title-only extraction', async () => {
  const r=await guidedFood(request(),{food:async()=>{throw Error('must not look up')},model:async()=>({dishes:[{name:'Chicken bowl',customizable:true,ingredients:[]}]})});
  assert.equal(r.status,'needs_ingredients');
  assert.equal(r.dishes?.[0].ingredients.find(x=>x.name.toLowerCase()==='chicken')?.state,'included');
});
