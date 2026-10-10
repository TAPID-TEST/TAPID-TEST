(function(){
 const $=id=>document.getElementById(id);
 function view(value){const approvals=value==='approvals';$('employerAnalytics').hidden=approvals;$('employerApprovalSection').hidden=!approvals;
 document.querySelectorAll('[data-employer-view]').forEach(b=>{const active=b.dataset.employerView===value;b.classList.toggle('active',active);b.setAttribute('aria-selected',String(active));});}
 $('employerViewTabs').addEventListener('click',e=>{const button=e.target.closest('[data-employer-view]');if(button)view(button.dataset.employerView);});
 view(new URLSearchParams(location.search).get('view')==='approvals'?'approvals':'analytics');
})();
