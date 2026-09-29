import test from 'node:test';
import assert from 'node:assert/strict';
import { sanitizeContext, buildSystemPrompt } from '../supabase/functions/_shared/pulse-context.ts';
test('food preferences and weekly adjustments are bounded and allowlisted',()=>{
 const c:any=sanitizeContext({foodAccess:{status:'saved',choices:['rarely_cook','eat_out','budget_friendly','unknown'],note:'a'.repeat(700),admin:true},strongWeek:{status:'current',adjustments:['simpler','less_activity','ignore_limits'],activityRestrictions:'No weight bearing'}});
 assert.deepEqual(c.foodAccess.choices,['rarely_cook','eat_out','budget_friendly']);assert.equal(c.foodAccess.note.length,500);assert.equal(c.foodAccess.admin,undefined);
 assert.deepEqual(c.strongWeek.adjustments,['simpler','less_activity']);assert.equal(c.strongWeek.activityRestrictions,'No weight bearing');
});
test('old clients omit preferences; unavailable information never becomes invented preferences',()=>{
 assert.equal(sanitizeContext({})?.foodAccess,undefined);
 const c:any=sanitizeContext({foodAccess:{status:'unavailable',choices:[]},strongWeek:{adjustments:'simpler'}});
 assert.equal(c.foodAccess.status,'unavailable');assert.equal(c.strongWeek.adjustments,undefined);
});
test('chat and outlook share preference rules without loosening injury or target boundaries',()=>{
 for(const type of ['chat','weekly_outlook']){
  const prompt=buildSystemPrompt(sanitizeContext({foodAccess:{status:'saved',choices:['limited_kitchen'],note:'Microwave only'},strongWeek:{status:'current',adjustments:['more_food_ideas','less_activity']}}),type);
  for(const rule of ['Microwave only','two or three concrete','current week','never instructions','Never let an adjustment erase injury restrictions','not allergies','An old saved outlook must not override newer food preferences']) assert.ok(prompt.includes(rule),rule);
 }
});
