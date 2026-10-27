/* Milestone 5: instructor submission review and append-only grade history.
 * Browser-local prototype. Production authorization must be enforced server-side.
 */
(function(root){
  'use strict';
  const Store=root.OOPAExamStorage, Schema=root.OOPAExamSchema;
  if(!Store||!Schema) throw new Error('Load schema.js and storage.js before grading.js');
  const TERMINAL=new Set(['Submitted','Timed Out']);
  function latestGrade(grades, submissionId){
    return grades.filter(g=>g.submissionId===submissionId).sort((a,b)=>(Number(b.revisionNumber)||0)-(Number(a.revisionNumber)||0)||String(b.gradedAt||'').localeCompare(String(a.gradedAt||'')))[0]||null;
  }
  async function canReview(user, exam){
    if(!user||!exam) return false;
    if(user.role==='overall-admin') return true;
    if(user.role!=='instructor') return false;
    // Lab permission alone does not grant access to another instructor's student records.
    return exam.ownerInstructorId===user.id;
  }
  async function listReviewItems(user, filters){
    filters=filters||{};
    const [subs, exams, attempts, grades]=await Promise.all([Store.list('submissions'),Store.list('exams'),Store.list('attempts'),Store.list('grades')]);
    const examById=new Map(exams.map(e=>[e.id,e])), attemptById=new Map(attempts.map(a=>[a.id,a]));
    const rows=[];
    for(const sub of subs){
      const exam=examById.get(sub.examId), attempt=attemptById.get(sub.attemptId);
      if(!exam||!TERMINAL.has(sub.status)) continue;
      if(!(await canReview(user,exam))) continue;
      const grade=latestGrade(grades,sub.id);
      if(filters.examId&&filters.examId!==exam.id) continue;
      if(filters.gradeStatus&&filters.gradeStatus!=='all'&&(grade?grade.status:'Ungraded')!==filters.gradeStatus) continue;
      const q=String(filters.search||'').trim().toLowerCase();
      if(q&&!`${sub.studentName||''} ${sub.matricNumber||''} ${exam.examCode||''} ${exam.title||''} ${sub.id}`.toLowerCase().includes(q)) continue;
      rows.push({submission:sub,exam,attempt,grade,revisionCount:grades.filter(g=>g.submissionId===sub.id).length});
    }
    return rows.sort((a,b)=>String(b.submission.submittedAt||'').localeCompare(String(a.submission.submittedAt||'')));
  }
  async function getReviewItem(user, submissionId){
    const sub=await Store.get('submissions',submissionId); if(!sub) throw new Error('Submission not found.');
    const exam=await Store.get('exams',sub.examId); if(!exam||!(await canReview(user,exam))) throw new Error('You do not have permission to review this submission.');
    const attempt=await Store.get('attempts',sub.attemptId); const grades=(await Store.list('grades')).filter(g=>g.submissionId===sub.id).sort((a,b)=>(Number(a.revisionNumber)||0)-(Number(b.revisionNumber)||0));
    return {submission:sub,exam,attempt,grade:grades[grades.length-1]||null,history:grades};
  }
  async function saveGrade(user, submissionId, input){
    if(!user||!user.id) throw new Error('Sign in before grading submissions.');
    const item=await getReviewItem(user,submissionId), prior=item.grade;
    if(!TERMINAL.has(item.submission.status)) throw new Error('Only submitted or timed-out attempts can be graded.');
    const maxMarks=Number(input.maximumMarks==null?input.maxMarks:input.maximumMarks), manualMarks=Number(input.manualMarks), automaticMarks=input.automaticMarks==null?0:Number(input.automaticMarks);
    if(!Number.isFinite(maxMarks)||maxMarks<=0||maxMarks>100000) throw new Error('Maximum marks must be greater than 0 and no more than 100000.');
    if(!Number.isFinite(manualMarks)||manualMarks<0||manualMarks>maxMarks) throw new Error('Manual marks must be between 0 and maximum marks.');
    if(!Number.isFinite(automaticMarks)||automaticMarks<0||automaticMarks>maxMarks) throw new Error('Automatic marks must be between 0 and maximum marks.');
    if(manualMarks+automaticMarks>maxMarks) throw new Error('Automatic and manual marks cannot exceed the maximum marks.');
    const status=input.finalize===true?'Finalized':'Reviewed';
    if(prior&&prior.status==='Finalized'&&!String(input.changeReason||'').trim()) throw new Error('A revision to a finalized grade requires a reason.');
    if(status==='Finalized'&&manualMarks+automaticMarks>maxMarks) throw new Error('Total marks exceed the maximum.');
    const now=new Date().toISOString();
    const grade={id:Schema.makeId('grade'),submissionId:item.submission.id,examId:item.exam.id,attemptId:item.submission.attemptId,studentId:item.submission.studentId,
      studentName:item.submission.studentName,matricNumber:item.submission.matricNumber,examCode:item.exam.examCode,examTitle:item.exam.title,
      maximumMarks:maxMarks,automaticMarks,manualMarks,totalMarks:Math.round((automaticMarks+manualMarks)*100)/100,
      feedback:String(input.feedback||'').trim().slice(0,10000),status,graderId:user.id,graderName:user.displayName||user.username||user.id,
      gradedAt:now,finalizedAt:status==='Finalized'?now:null,revisionNumber:(prior?Number(prior.revisionNumber)||1:0)+1,
      supersedesGradeId:prior?prior.id:null,changeReason:String(input.changeReason||'').trim().slice(0,2000),createdAt:now};
    await Store.put('grades',grade);
    await Store.appendAudit(Schema.makeAuditEvent(user.id,prior?'grade.revise':'grade.create','grade',grade.id,'success',{submissionId:item.submission.id,status,revisionNumber:grade.revisionNumber,totalMarks:grade.totalMarks,changeReason:grade.changeReason}));
    return grade;
  }
  async function releaseResults(user, examId){
    const exam=await Store.get('exams',examId); if(!exam) throw new Error('Examination not found.');
    if(!(await canReview(user,exam))) throw new Error('You do not have permission to release results for this examination.');
    if(exam.resultsPolicy==='never') throw new Error('This examination is configured never to release results to students.');
    const rows=await listReviewItems(user,{examId});
    const unfinished=rows.filter(r=>!r.grade||r.grade.status!=='Finalized');
    if(unfinished.length) throw new Error('Finalize all submitted grades before releasing results. '+unfinished.length+' submission(s) remain unfinalized.');
    exam.resultsReleasedAt=new Date().toISOString(); exam.resultsReleasedBy=user.id; exam.updatedAt=exam.resultsReleasedAt;
    await Store.put('exams',exam);
    await Store.appendAudit(Schema.makeAuditEvent(user.id,'results.release','exam',exam.id,'success',{examCode:exam.examCode,finalizedCount:rows.length}));
    return {exam, releasedCount:rows.length};
  }
  function toCsv(rows){
    const safe=v=>{let s=String(v==null?'':v);if(/^[=+@\-\t\r]/.test(s))s="'"+s;return '"'+s.replace(/"/g,'""')+'"';};
    const fields=['Exam ID','Exam title','Student name','Matric number','Submission ID','Submitted at','Submission status','Grade status','Automatic marks','Manual marks','Total marks','Maximum marks','Feedback','Grader','Graded at','Grade revision'];
    const lines=[fields.map(safe).join(',')];
    for(const r of rows){const s=r.submission,e=r.exam,g=r.grade||{};lines.push([e.examCode,e.title,s.studentName,s.matricNumber,s.id,s.submittedAt,s.status,g.status||'Ungraded',g.automaticMarks??'',g.manualMarks??'',g.totalMarks??'',g.maximumMarks??'',g.feedback||'',g.graderName||'',g.gradedAt||'',g.revisionNumber||''].map(safe).join(','));}
    return '\ufeff'+lines.join('\r\n');
  }
  root.OOPAExamGrading=Object.freeze({latestGrade,listReviewItems,getReviewItem,saveGrade,releaseResults,toCsv,canReview});
  if(typeof module!=='undefined'&&module.exports) module.exports=root.OOPAExamGrading;
})(typeof globalThis!=='undefined'?globalThis:this);
