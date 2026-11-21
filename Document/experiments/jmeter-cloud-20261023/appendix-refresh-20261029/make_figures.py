from pathlib import Path
from statistics import median
import hashlib
import json

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

R=Path(__file__).parent
data=json.loads((R/'evidence/accepted-run-details.json').read_text())
OUT=R/'figures';OUT.mkdir(exist_ok=True)
plt.rcParams.update({'font.family':'Times New Roman','font.size':12,'axes.spines.top':False,'axes.spines.right':False})
TEAL='#0B6670';GRAY='#697A8A';RED='#9B2C2C';AMBER='#B97813';INK='#20262E'
PROFILES=['p50','p100','p500','soak','spike']
LABELS={'p50':'50 VU','p100':'100 VU','p500':'500 VU','soak':'100-VU soak','spike':'Spike'}
WINDOW={'p50':'Scored hold: 120–720 s','p100':'Scored hold: 120–720 s','p500':'Scored hold: 120–720 s','soak':'Scored hold: 120–2820 s (45 min)','spike':'Latency/throughput: 500-VU peak, 180–480 s; errors: all scored phases'}
manifest=[]

def nice(v): return f'{v:,.0f}'
for side,start_no in [('before',9),('after',14)]:
    for offset,profile in enumerate(PROFILES):
        records=sorted([x for x in data if x['row']['profile']==profile and x['row']['side']==side],key=lambda x:x['row']['repeat'])
        rows=[x['row'] for x in records]
        passes=sum(x['performance_gate']=='PASS' for x in rows)
        title=f"Controlled cloud {'baseline' if side=='before' else 'remediation'} | {LABELS[profile]}"
        fig=plt.figure(figsize=(8,7.6),dpi=230,facecolor='white')
        fig.text(.05,.973,title,fontsize=17,fontweight='bold',color=INK,va='top')
        dates=' / '.join(sorted({x['start_bangkok'][8:10] for x in rows}))+' Oct 2026'
        fig.text(.05,.934,f"JMeter 5.5 | source {rows[0]['source_commit'][:8]} | {dates} (Bangkok)",fontsize=11,color=GRAY)
        fig.text(.05,.91,WINDOW[profile],fontsize=10.5,color=INK)
        fig.text(.05,.884,f"Validity: 3/3 PASS  •  Performance: {passes}/3 PASS, {3-passes}/3 FAIL",fontsize=11.5,fontweight='bold',color=TEAL if passes==3 else RED)
        ax=fig.add_axes([.05,.71,.90,.145]);ax.axis('off')
        cells=[[x['run_id'],nice(x['p95_ms']),nice(x['p99_ms']),f"{x['requests_per_second']:,.2f}",f"{x['error_pct']:.2f}",x['performance_gate']] for x in rows]
        tab=ax.table(cellText=cells,colLabels=['Accepted run ID','p95 ms','p99 ms','Req/s','Errors %','Gate'],colWidths=[.39,.115,.115,.14,.105,.135],cellLoc='center',bbox=[0,0,1,1])
        tab.auto_set_font_size(False);tab.set_fontsize(11)
        for (ri,ci),cell in tab.get_celld().items():
            cell.set_edgecolor('#D0D7DD');cell.set_linewidth(.6)
            if ri==0: cell.set_facecolor(TEAL);cell.set_text_props(color='white',weight='bold')
            elif ri%2: cell.set_facecolor('#F2F6F7')
        ax=fig.add_axes([.08,.395,.85 if profile in PROFILES[:3] else .39,.245])
        xx=np.arange(3)
        b1=ax.bar(xx-.18,[x['p95_ms'] for x in rows],.34,color=TEAL,label='p95')
        b2=ax.bar(xx+.18,[x['p99_ms'] for x in rows],.34,color=GRAY,label='p99')
        ax.set_xticks(xx,['R1','R2','R3']);ax.set_ylabel('Response time (ms)')
        ax.set_title('Per-repeat latency — no run omitted',fontsize=12)
        for bars in (b1,b2):
            ax.bar_label(bars,labels=[nice(b.get_height()) for b in bars],padding=3,fontsize=10.5)
        maxval=max(x['p99_ms'] for x in rows)
        if profile in PROFILES[:3]:
            limit={'p50':300,'p100':500,'p500':1200}[profile]
            ax.axhline(limit,ls='--',color=RED,lw=1.1,label=f'p95 limit {limit:,} ms')
            maxval=max(maxval,limit)
        ax.set_ylim(0,maxval*1.28);ax.grid(axis='y',alpha=.18);ax.set_axisbelow(True)
        ax.legend(loc='upper left',fontsize=10,ncol=3 if profile in PROFILES[:3] else 2,frameon=False)
        if profile in ['soak','spike']:
            ax=fig.add_axes([.58,.395,.34,.245])
            drift=[x['drift_pct'] for x in rows]
            bars=ax.bar(xx,drift,color=[TEAL if v<=20 else RED for v in drift],width=.5)
            ax.bar_label(bars,labels=[f'{v:.2f}%' for v in drift],padding=3,fontsize=10.5)
            ax.axhline(20,ls='--',color=AMBER,label='≤20% gate')
            ax.set_ylim(0,max(25,max(drift)*1.3));ax.set_xticks(xx,['R1','R2','R3']);ax.set_ylabel('Relative p95 drift (%)')
            ax.set_title('Soak drift' if profile=='soak' else 'Recovery / base drift',fontsize=12)
            ax.grid(axis='y',alpha=.18);ax.set_axisbelow(True);ax.legend(fontsize=10,frameon=False)
            ax=fig.add_axes([.07,.17,.87,.14]);ax.axis('off')
            phases=[]
            for record in records:
                summary=record['summary']
                first,last=(summary['soak']['first_10_minutes'],summary['soak']['last_10_minutes']) if profile=='soak' else (summary['phases']['base'],summary['phases']['recovery'])
                phases.append([f"R{record['row']['repeat']}",nice(first['p95_ms']),nice(last['p95_ms']),f"{record['row']['drift_pct']:.2f}%"])
            labels=['Repeat','First 10 min p95, ms','Last 10 min p95, ms','Drift'] if profile=='soak' else ['Repeat','100-VU base p95, ms','100-VU recovery p95, ms','Drift']
            tab=ax.table(cellText=phases,colLabels=labels,cellLoc='center',bbox=[0,0,1,1]);tab.auto_set_font_size(False);tab.set_fontsize(11)
            for (ri,ci),cell in tab.get_celld().items():
                cell.set_edgecolor('#D0D7DD');cell.set_linewidth(.6)
                if ri==0: cell.set_facecolor('#E7EFF1');cell.set_text_props(weight='bold')
        else:
            ax=fig.add_axes([.20,.135,.72,.19])
            labels=['GET /reports/account-ledger','GET /reports/trial-balance','GET /reports/profit-loss','GET /reports/balance-sheet','POST /journal-entries/bulk']
            values=[median(x['summary']['endpoints'][label]['p95_ms'] for x in records) for label in labels]
            bars=ax.barh(np.arange(5),values,color=TEAL,height=.6)
            ax.set_yticks(np.arange(5),['Ledger','Trial balance','Profit/loss','Balance sheet','Bulk write']);ax.invert_yaxis()
            ax.set_xlabel('Selected endpoint p95 median across three runs (ms)',fontsize=11)
            ax.bar_label(bars,labels=[nice(v) for v in values],padding=4,fontsize=10)
            ax.set_xlim(0,max(values)*1.20);ax.grid(axis='x',alpha=.18);ax.set_axisbelow(True)
        sql=median(x['resource']['target']['scored_hold']['containers']['jmeter-research-sql-1']['cpu_throttled_period_fraction']*100 for x in records)
        ram=[]
        for role,container in [('target','jmeter-research-api-1'),('target','jmeter-research-sql-1'),('generator','jmeter-research-jmeter')]:
            ram.append(median(x['resource'][role]['scored_hold']['containers'][container]['memory_peak_pct_of_limit'] for x in records))
        fig.text(.05,.066,f"SQL throttled periods: {sql:.2f}%. Peak RAM (% cap), API / SQL / JMeter: {ram[0]:.1f} / {ram[1]:.1f} / {ram[2]:.1f}.",fontsize=10,color=INK)
        fig.text(.05,.039,'Research figure from scored JMeter files; analysis v2. Resource values are medians of three runs.',fontsize=10,color=GRAY)
        fig.text(.05,.018,'p99 has no pass threshold. Run IDs and raw hashes: accepted-runs.csv and figure provenance.',fontsize=10,color=GRAY)
        filename=f'figure-L-{start_no+offset:02d}-{profile}-{side}.png'
        path=OUT/filename
        fig.savefig(path,dpi=230);plt.close(fig)
        manifest.append({'figure':f'L.{start_no+offset}','profile':profile,'side':side,'file':filename,'run_ids':[x['run_id'] for x in rows],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_commit':rows[0]['source_commit'],'validity_passes':3,'performance_passes':passes})
        print('created',filename,flush=True)
(OUT/'figure-provenance.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
