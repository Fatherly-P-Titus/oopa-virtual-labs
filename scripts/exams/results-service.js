/* Milestone 6: student-facing results lookup. Browser-local prototype only. */
(function(root){
  'use strict';
  const Store=root.OOPAExamStorage, Schema=root.OOPAExamSchema;
  if(!Store||!Schema) throw new Error('Load schema.js and storage.js before results-service.js');
  const norm=s=>String(s||'').trim().toLocaleLowerCase();
  async function lookupResult(input){
    const code=String(input.examCode||'').trim().toUpperCase();
    const matric=Schema.normalizeMatric(input.matricNumber);
    const name=norm(input.studentName);
    if(!code) throw new Error('Enter the examination ID.');
    if(!name) throw new Error('Enter your full name.');
    if(root.OOPABackend&&root.OOPABackend.enabled&&root.OOPABackend.enabled()){
      const cfg=root.OOPABackendConfig||{};const response=await fetch(root.OOPABackend.functionUrl('student-gateway'),{method:'POST',headers:{'Content-Type':'application/json','apikey':cfg.anonKey||''},body:JSON.stringify({action:'results',examCode:code,name:String(input.studentName||'').trim(),matricNumber:matric})});const data=await response.json().catch(()=>({}));if(!response.ok)throw new Error(data.error||'Could not retrieve results.');return data;
    }
    const exam=(await Store.list('exams')).find(e=>String(e.examCode||'').toUpperCase()===code);
    if(!exam) throw new Error('No examination matches that ID. Check the ID and try again.');
    if(exam.resultsPolicy==='never') throw new Error('Results for this examination are not available to students under its results policy.');
    if(exam.resultsPolicy!=='immediate'&&!exam.resultsReleasedAt) throw new Error('Your instructor has not released results for this examination yet.');
    const snapshots=(await Store.list('eligibilitySnapshots')).filter(s=>s.examId===exam.id);
    const eligible=snapshots.flatMap(s=>s.students||[]).find(s=>Schema.normalizeMatric(s.matricNumber)===matric&&norm(s.name)===name);
    if(!eligible) throw new Error('The supplied name and matric number do not match an eligible student record for this examination.');
    const submissions=(await Store.list('submissions')).filter(s=>s.examId===exam.id&&Schema.normalizeMatric(s.matricNumber)===matric&&norm(s.studentName)===name&&['Submitted','Timed Out'].includes(s.status));
    if(!submissions.length) throw new Error('No submitted attempt was found for this student and examination.');
    const grades=await Store.list('grades');
    const reports=submissions.map(sub=>{
      const history=grades.filter(g=>g.submissionId===sub.id).sort((a,b)=>(Number(a.revisionNumber)||0)-(Number(b.revisionNumber)||0));
      return {submission:sub,grade:history[history.length-1]||null,history};
    }).filter(r=>r.grade&&r.grade.status==='Finalized').sort((a,b)=>String(b.grade.finalizedAt||b.grade.gradedAt||'').localeCompare(String(a.grade.finalizedAt||a.grade.gradedAt||'')));
    if(!reports.length) throw new Error('Your submission is recorded, but a finalized grade is not available yet.');
    const result={exam:{id:exam.id,examCode:exam.examCode,title:exam.title,resultsPolicy:exam.resultsPolicy,resultsReleasedAt:exam.resultsReleasedAt||null},student:{name:eligible.name,matricNumber:eligible.matricNumber},reports,issuedAt:new Date().toISOString()};
    await Store.appendAudit(Schema.makeAuditEvent('student-results','results.lookup','exam',exam.id,'success',{examCode:exam.examCode,matricNumber:matric,reportCount:reports.length}));
    return result;
  }
  function toReportText(result){
    const lines=['OOPA VIRTUAL LABS — STUDENT RESULT','Examination: '+result.exam.title,'Exam ID: '+result.exam.examCode,'Student: '+result.student.name,'Matric number: '+result.student.matricNumber,'Results policy: '+result.exam.resultsPolicy,''];
    result.reports.forEach((r,i)=>{const g=r.grade,s=r.submission;lines.push('Attempt '+(i+1),'Submission ID: '+s.id,'Submitted: '+(s.submittedAt||'—'),'Status: '+s.status,'Score: '+g.totalMarks+' / '+g.maximumMarks,'Percentage: '+(Math.round((g.totalMarks/g.maximumMarks)*10000)/100)+'%','Feedback: '+(g.feedback||'No feedback recorded.'),'');});
    lines.push('Generated: '+new Date(result.issuedAt).toLocaleString(),'This report was generated from OOPA Virtual Labs records.');
    return lines.join('\n');
  }
  root.OOPAExamResults=Object.freeze({lookupResult,toReportText});
  if(typeof module!=='undefined'&&module.exports) module.exports=root.OOPAExamResults;
})(typeof globalThis!=='undefined'?globalThis:this);
