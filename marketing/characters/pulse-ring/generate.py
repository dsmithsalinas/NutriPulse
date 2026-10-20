#!/usr/bin/env python3
"""Rebuild canonical Pulse SVGs. Standard library only; no raster dependencies."""
from pathlib import Path
import math, json, argparse
STATES={'ready':'Ready','listening':'Listening','thinking':'Thinking','progress':'Progress','floor-cleared':'Floor Cleared','check-in':'Check-in','rest':'Rest','coaching':'Pulse Coaching'}
SIZES=(32,48,80)
NODE=(18.99,61.29,7.5)

def arc(start,end,r=33):
    def point(deg):
        a=math.radians(deg-90);return (50+r*math.cos(a),50+r*math.sin(a))
    x,y=point(start);a,b=point(end)
    return f'M{x:.4f} {y:.4f} A{r} {r} 0 {int(end-start>180)} 1 {a:.4f} {b:.4f}'

def svg(state,dark=False,size=80,progress=.6):
    if not math.isfinite(progress):
        raise ValueError('Progress must be finite')
    progress=max(0.0,min(1.0,progress))
    active='#C7D2FE' if dark else '#4F46E5'
    neutral='#CBD5E1' if dark else '#0F172A'
    color=neutral if state in ('ready','rest','check-in') else active
    track='#817EA6' if dark else '#B8BFCD'
    if state=='floor-cleared':color='#D9F99D' if dark else '#4D7C0F'
    def path(d,stroke=color,width=6,extra=''):
        return f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
    pieces=[f'<circle data-part="track" cx="50" cy="50" r="33" fill="none" stroke="{track}" stroke-width="6"/>']
    if state=='progress':
        if progress>=1:pieces.append(f'<circle data-part="active" cx="50" cy="50" r="33" fill="none" stroke="{color}" stroke-width="6"/>')
        elif progress>0:pieces.append(path(arc(0,360*progress),extra='data-part="active"'))
    elif state=='floor-cleared':
        pieces.append('<circle data-part="active" cx="50" cy="50" r="33" fill="none" stroke="#D9F99D" stroke-width="6"/>')
        if not dark:
            pieces.extend(f'<circle cx="50" cy="50" r="{r}" fill="none" stroke="#4D7C0F" stroke-width="1.5"/>' for r in (30,36))
    else:
        pieces.append(path(arc(0,250),extra='data-part="active"'))
    if state=='thinking':
        # Short highlighted section travels within the existing ring, never orbits the node.
        pieces.append(path(arc(60,96),stroke='#EEF1F6' if dark else '#1E1B4B',width=6,extra='data-part="considering-segment"'))
    if state=='listening':pieces.append(path('M41 46V54 M50 40V60 M59 46V54',width=4,extra='data-part="waveform"'))
    if state=='floor-cleared':
        pieces.append('<circle cx="50" cy="50" r="14" fill="#D9F99D"/>')
        pieces.append(path('M43 50L48 55L57 45',stroke='#1A2E05',width=4))
    if state=='rest':pieces.append(f'<path d="M54 37 A14 14 0 1 0 63 59 A16 16 0 0 1 54 37Z" fill="{color}"/>')
    if state=='coaching':pieces.append(path('M37 50H41 C44 50 44 41 47 41 S50 59 53 59 S56 50 59 50 H63',width=4,extra='data-part="guidance-wave"'))
    if state=='check-in':pieces.append(path('M42 50H58',width=4,extra='data-part="pause"'))
    # Fixed node: identical circle geometry in every state, never attached to live progress.
    fill='#D9F99D' if state=='floor-cleared' else color
    pieces.append(f'<circle data-part="signature-node" cx="18.99" cy="61.29" r="7.5" fill="{fill}"/>')
    if state=='floor-cleared' and not dark:
        pieces.append('<circle cx="18.99" cy="61.29" r="6.75" fill="none" stroke="#4D7C0F" stroke-width="1.5"/>')
    label='Pulse: '+STATES[state]+(f' — {progress:.0%}' if state=='progress' else '')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}" role="img" aria-label="{label}">\n  '+'\n  '.join(pieces)+'\n</svg>\n'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output-dir',type=Path,default=Path(__file__).parent/'svg');args=parser.parse_args()
    files=[]
    for state in STATES:
        for dark in (False,True):
            name=state+('-dark' if dark else '')+'.svg'
            for size in (None,*SIZES):
                rel=Path(name) if size is None else Path(str(size))/name
                p=args.output_dir/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(svg(state,dark,size or 80));files.append(str(rel))
    (args.output_dir.parent/'manifest.json').write_text(json.dumps({'version':2,'canonical_spec':'docs/pulse-ring-system.md','viewBox':[0,0,100,100],'sizes':SIZES,'node':NODE,'states':STATES,'progress_example':.6,'files':files},indent=2)+'\n')
    print(f'Exported {len(files)} SVGs')
if __name__=='__main__':main()
