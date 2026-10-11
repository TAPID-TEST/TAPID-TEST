(function(){
 'use strict';
 const node=document.getElementById('major'),search=document.getElementById('majorSearch'),college=document.getElementById('majorCollege');
 let list=[],chosen='',sequence=0;
 function render(){
  const query=(search?.value||'').trim().toLowerCase();node.replaceChildren();
  const blank=document.createElement('option');blank.value='';blank.textContent='Select an official major';node.append(blank);
  for(const row of list.filter(r=>r.name===chosen||!query||r.name.toLowerCase().includes(query))){const o=document.createElement('option');o.value=row.name;o.textContent=row.name;node.append(o);}
  node.value=chosen;const match=list.find(r=>r.name===chosen);if(college)college.value=match?.college_name||'';
 }
 window.TapIDMajors={async populate(school,previous=''){
  if(!node)return;const token=++sequence;node.disabled=true;
  const isCalPoly=window.TapIDProgramCatalog.isCalPoly(school);
  list=isCalPoly?(window.CalPolyPrograms||[]):[];chosen=list.find(r=>r.name.toLowerCase()===previous.trim().toLowerCase())?.name||'';if(search)search.value='';render();
  // Render the included Cal Poly catalog immediately; configured catalogs may extend it.
  node.disabled=!list.length;node.setCustomValidity(list.length?'':'Your university program list needs to be configured.');
  const hadLocal=list.length>0;try{const result={data:await window.TapIDProgramCatalog.load(school)};if(token!==sequence)return;
   if(!result.error&&result.data?.length){const wanted=hadLocal?node.value:previous;list=result.data;chosen=list.find(r=>r.name.toLowerCase()===wanted.trim().toLowerCase())?.name||'';render();node.disabled=false;node.setCustomValidity('');}
  }catch(error){/* The included catalog keeps Cal Poly selection available. */}
 }};
 search?.addEventListener('input',render);node?.addEventListener('change',()=>{chosen=node.value;render();});
 document.getElementById('school')?.addEventListener('change',e=>TapIDMajors.populate(e.target.value));
})();
