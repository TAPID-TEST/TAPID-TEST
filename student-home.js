(function(root){
 root.TapIDStudentHome={
  latestConnections(rows){return [...rows].sort((a,b)=>{const date=x=>{const n=Date.parse(x.connected_at);return Number.isFinite(n)?n:0;};return date(b)-date(a);}).slice(0,5);},
  notificationTarget(href,current){try{const url=new URL(href,current),base=new URL(current);const target=url.hash.slice(1);return url.origin===base.origin&&url.pathname===base.pathname&&['home','notifications','connections','messages','career-fairs','outcomes','profile','share'].includes(target)?target:null;}catch{return null;}}
 };
})(typeof window==='undefined'?globalThis:window);
