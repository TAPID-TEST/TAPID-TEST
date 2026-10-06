(function(root){
'use strict';
function parseCsv(text){
  text=String(text).replace(/^\uFEFF/,'');const rows=[];let row=[],cell='',quoted=false,closed=false;
  for(let i=0;i<text.length;i++){
    const c=text[i];
    if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++;}else{quoted=false;closed=true;}}else cell+=c;continue;}
    if(c==='"'){if(cell.trim()||closed)throw new Error('Unexpected quote in CSV. Export the file as CSV again.');quoted=true;}
    else if(c===','){row.push(cell.trim());cell='';closed=false;}
    else if(c==='\n'||c==='\r'){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell.trim());if(row.some(Boolean))rows.push(row);row=[];cell='';closed=false;}
    else{if(closed&&c.trim())throw new Error('Unexpected text after a quoted CSV value.');cell+=c;}
  }
  if(quoted)throw new Error('A quoted CSV value is not closed.');row.push(cell.trim());if(row.some(Boolean))rows.push(row);
  return rows;
}
function review(text,existing=[]){
  const parsed=parseCsv(text);if(!parsed.length)throw new Error('The CSV is empty.');
  const headers=parsed.shift().map(x=>x.toLowerCase().trim().replace(/\s+/g,'_'));
  const nameColumn=headers.indexOf('company_name'),externalColumn=headers.indexOf('external_employer_id');
  if(nameColumn<0)throw new Error('The CSV needs a company_name column. Download the template to start.');
  if(new Set(headers).size!==headers.length)throw new Error('The CSV has duplicate column headings.');
  if(!parsed.length)throw new Error('Add at least one company below the column heading.');
  if(parsed.length>2000)throw new Error('Import up to 2,000 companies at a time.');
  const seen=new Set(existing.map(x=>x.name.trim().toLowerCase()));const valid=[],errors=[];let duplicates=0;
  parsed.forEach((cols,i)=>{
    const name=cols[nameColumn]||'';
    if(cols.length!==headers.length){errors.push(`Row ${i+2}: column count does not match the header.`);return;}
    if(!name||name.length>200){errors.push(`Row ${i+2}: enter a company name of 1–200 characters.`);return;}
    const key=name.toLowerCase();if(seen.has(key)){duplicates++;return;}seen.add(key);
    valid.push({name,external_id:externalColumn<0?'':cols[externalColumn]||'',company_id:null,saved:false});
  });
  return {valid,errors,duplicates,total:parsed.length};
}
const api={parseCsv,review};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.TapIDFairImport=api;
})(typeof window!=='undefined'?window:globalThis);
