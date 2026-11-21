from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
d=Path(__file__).parent;a=json.loads((d/'analysis.json').read_text())
plt.rcParams.update({'font.family':'Times New Roman','font.size':10})
fig,axes=plt.subplots(2,3,figsize=(10,6.5),layout='constrained')
for i,profile in enumerate(['p50','p100','p500','soak','spike']):
 ax=axes.flat[i];kind='latency' if i<3 else 'drift';key='p95_limit_ms' if i<3 else 'drift_limit_pct'
 for side,color,mark in [('before','#6B7885','s'),('after','#0B6670','o')]:
  rows=[r for r in a[kind] if r['profile']==profile and r['side']==side]
  ax.plot([r[key] for r in rows],[r['passes'] for r in rows],marker=mark,color=color,label=side.title(),alpha=.85)
 ax.axvline([300,500,1200,20,20][i],color='#A23F35',ls=':',label='Original limit')
 ax.set_ylim(-.15,3.3);ax.set_yticks([0,1,2,3]);ax.set_ylabel('Passing runs out of 3');ax.set_xlabel('p95 limit (ms)' if i<3 else 'Drift limit (%)')
 ax.set_title(['50 virtual users','100 virtual users','500 virtual users','Soak stability','Spike recovery'][i]);ax.grid(alpha=.18)
axes.flat[5].axis('off');h,l=axes.flat[0].get_legend_handles_labels();axes.flat[5].legend(h,l,loc='upper left',frameon=False)
axes.flat[5].text(0,.45,'Post-hoc sensitivity analysis\nPoints show tested thresholds.\nOriginal error ceilings retained.\nAll 30 accepted runs included.\nLines connect evaluated points.',va='top')
fig.savefig(d/'sensitivity.png',dpi=210);plt.close(fig)
