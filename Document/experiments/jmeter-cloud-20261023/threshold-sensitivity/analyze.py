from pathlib import Path
from decimal import Decimal
import csv,json,hashlib
d=Path(__file__).parent
source=Path('Document/experiments/jmeter-cloud-20261023/appendix-refresh-20261029/evidence/accepted-runs.csv')
data=list(csv.DictReader(source.open()));assert len(data)==30 and all(r['validity']=='PASS' and Decimal(r['error_pct'])==0 for r in data)
groups={(p,s):[r for r in data if r['profile']==p and r['side']==s] for p in ['p50','p100','p500','soak','spike'] for s in ['before','after']}
assert all(len(r)==3 for r in groups.values())
lat=[];drift=[]
for multiplier in ['0.50','0.75','1.00','1.25','1.50','2.00']:
 for profile,base,error in [('p50',300,.5),('p100',500,1),('p500',1200,2)]:
  limit=Decimal(multiplier)*base
  for side in ['before','after']:
   rows=groups[profile,side];passing=[r['run_id'] for r in rows if Decimal(r['p95_ms'])<=limit and Decimal(r['error_pct'])<=Decimal(str(error))]
   lat.append(dict(profile=profile,side=side,multiplier=multiplier,p95_limit_ms=int(limit),error_limit_pct=error,passes=len(passing),runs=3,passing_run_ids=passing))
for limit in [10,20,30,40,50,80,100]:
 for profile,error in [('soak',1),('spike',3)]:
  for side in ['before','after']:
   rows=groups[profile,side];passing=[r['run_id'] for r in rows if Decimal(r['drift_pct'])<=limit and Decimal(r['error_pct'])<=error]
   drift.append(dict(profile=profile,side=side,drift_limit_pct=limit,error_limit_pct=error,passes=len(passing),runs=3,passing_run_ids=passing))
for r in lat+drift:
 if r.get('multiplier')=='1.00' or r.get('drift_limit_pct')==20:assert r['passes']==sum(x['performance_gate']=='PASS' for x in groups[r['profile'],r['side']])
maxima={p:{s:max(Decimal(r['p95_ms' if p.startswith('p') else 'drift_pct']) for r in groups[p,s]) for s in ['before','after']} for p in ['p50','p100','p500','soak','spike']}
result={'analysis':'Post-hoc threshold sensitivity using all 30 accepted runs','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'latency':lat,'drift':drift,'largest_observed_values':{p:{s:str(v) for s,v in a.items()} for p,a in maxima.items()},'inference':'Descriptive counts for three repeats per revision. Error ceilings held at original values. Original acceptance decisions retained. Threshold ranges are declared analysis choices.'}
(d/'analysis.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result['largest_observed_values']))
for q in ['latency','drift']:
 for x in result[q]:
  if x['side']=='after':print(q,x['profile'],x.get('p95_limit_ms',x.get('drift_limit_pct')),x['passes'])
