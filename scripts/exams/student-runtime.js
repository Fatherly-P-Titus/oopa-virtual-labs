/* Milestone 4: student exam runtime services. Browser-local prototype only. */
(function (root) {
  'use strict';
  const Store = root.OOPAExamStorage, Schema = root.OOPAExamSchema, Registry = root.OOPAExamLabRegistry;
  if (!Store || !Schema || !Registry) throw new Error('Load schema.js, storage.js and lab-registry.js before student-runtime.js');
  const encoder = new TextEncoder();
  const BACKEND_TOKEN_KEY='oopa.backend.student-attempts.v1';
  function backendEnabled(){return !!(root.OOPABackend&&root.OOPABackend.enabled&&root.OOPABackend.enabled());}
  async function backendCall(payload){
    if(!backendEnabled()) throw new Error('Backend mode is not enabled.');
    const cfg=root.OOPABackendConfig||{}; const response=await fetch(root.OOPABackend.functionUrl('student-gateway'),{method:'POST',headers:{'Content-Type':'application/json','apikey':cfg.anonKey||''},body:JSON.stringify(payload)});
    const data=await response.json().catch(()=>({})); if(!response.ok)throw new Error(data.error||'The examination service could not complete this request.'); return data;
  }
  function readTokens(){try{return JSON.parse(root.sessionStorage.getItem(BACKEND_TOKEN_KEY)||'{}')}catch(_){return {}}}
  function saveToken(attemptId,examCode,token){const all=readTokens();all[attemptId]={examCode,token};try{root.sessionStorage.setItem(BACKEND_TOKEN_KEY,JSON.stringify(all))}catch(_){throw new Error('Session storage is unavailable; keep this exam tab open.')}}
  function getToken(attemptId,examCode){const all=readTokens(),row=all[attemptId];if(!row||!row.token|| (examCode&&row.examCode!==examCode))throw new Error('This browser session cannot resume the attempt. Re-enter the exam details and access code.');return row}
  function removeToken(attemptId){const all=readTokens();delete all[attemptId];try{root.sessionStorage.setItem(BACKEND_TOKEN_KEY,JSON.stringify(all))}catch(_){}}

  function hex(bytes) { return Array.from(new Uint8Array(bytes)).map(x => x.toString(16).padStart(2, '0')).join(''); }
  async function verifyAccessCode(code, encoded) {
    if (!/^\d{6}$/.test(String(code || '')) || !root.crypto || !root.crypto.subtle) return false;
    const p = String(encoded || '').split(':');
    if (p.length !== 4 || p[0] !== 'pbkdf2-sha256' || p[1] !== '210000' || !/^[a-f0-9]{32}$/.test(p[2]) || !/^[a-f0-9]{64}$/.test(p[3])) return false;
    const salt = Uint8Array.from(p[2].match(/.{2}/g), x => parseInt(x, 16));
    const key = await root.crypto.subtle.importKey('raw', encoder.encode(String(code)), 'PBKDF2', false, ['deriveBits']);
    const result = hex(await root.crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations: 210000, hash: 'SHA-256' }, key, 256));
    let diff = 0; for (let i = 0; i < result.length; i++) diff |= result.charCodeAt(i) ^ p[3].charCodeAt(i);
    return diff === 0;
  }
  function examIsAvailable(exam, now) {
    const t = Number(now == null ? Date.now() : now);
    if (!exam || exam.status !== 'Published') return { ok: false, reason: 'This examination is not currently published.' };
    if (exam.availableFrom && t < Date.parse(exam.availableFrom)) return { ok: false, reason: 'This examination has not opened yet.' };
    if (exam.availableUntil && t >= Date.parse(exam.availableUntil)) return { ok: false, reason: 'This examination has closed to new attempts.' };
    return { ok: true };
  }
  async function findPublishedExam(code, options) {
    const needle = String(code || '').trim().toUpperCase();
    if(backendEnabled()){const data=await backendCall({action:'lookup',examCode:needle});const exam=data.exam;const availability=examIsAvailable(exam);if(!availability.ok&&!(options&&options.allowResume))throw new Error(availability.reason);const lab=Registry.getById(exam.labId);if(!lab)throw new Error('The laboratory for this examination is unavailable. Contact the instructor.');return {exam,lab};}
    if (!needle) throw new Error('Enter the examination ID.');
    const exam = (await Store.list('exams')).find(e => String(e.examCode || '').toUpperCase() === needle);
    if (!exam) throw new Error('No examination matches that ID. Check the ID and try again.');
    const availability = examIsAvailable(exam);
    if (!availability.ok) throw new Error(availability.reason);
    const lab = Registry.getById(exam.labId);
    if (!lab) throw new Error('The laboratory for this examination is unavailable. Contact the instructor.');
    return { exam, lab };
  }
  async function verifyStudent(exam, name, matricNumber, accessCode) {
    if(backendEnabled()){const data=await backendCall({action:'verify',examCode:exam.examCode,name:String(name||'').trim(),matricNumber:String(matricNumber||'').trim(),accessCode:String(accessCode||'')});if(data.activeAttempt&&data.attemptToken)saveToken(data.activeAttempt.id,exam.examCode,data.attemptToken);try{root.sessionStorage.setItem('oopa.backend.verified:'+exam.examCode,JSON.stringify({student:data.student,verificationToken:data.verificationToken||''}));}catch(_){}return {student:data.student,activeAttempt:data.activeAttempt||null,attemptsUsed:Number(data.attemptsUsed)||0};}
    const studentName = String(name || '').trim();
    if (!studentName || studentName.length > 160) throw new Error('Enter your full name (maximum 160 characters).');
    const matric = Schema.normalizeMatric(matricNumber);
    const availability = examIsAvailable(exam);
    if (!availability.ok) throw new Error(availability.reason);
    const snapshots = await Store.list('eligibilitySnapshots');
    const snapshot = snapshots.find(s => s.examId === exam.id);
    if (!snapshot) throw new Error('This examination has no eligibility snapshot. Contact the instructor.');
    const eligible = (snapshot.students || []).find(s => Schema.normalizeMatric(s.matricNumber) === matric);
    if (!eligible) throw new Error('That matric number is not on the authorized list for this examination.');
    if (String(eligible.name || '').trim().toLocaleLowerCase() !== studentName.toLocaleLowerCase()) throw new Error('The name does not match the authorized student record. Check spelling or contact the instructor.');
    if (!(await verifyAccessCode(accessCode, exam.accessCodeHash))) throw new Error('The access code is incorrect.');
    const attempts = (await Store.list('attempts')).filter(a => a.examId === exam.id && a.studentId === eligible.id && !['Cancelled', 'Invalidated'].includes(a.status));
    const active = attempts.find(a => a.status === 'In Progress');
    if (active) return { student: eligible, activeAttempt: active, attemptsUsed: attempts.length };
    if (attempts.length >= Number(exam.attemptLimit || 1)) throw new Error('You have used the maximum number of attempts for this examination.');
    return { student: eligible, activeAttempt: null, attemptsUsed: attempts.length };
  }
  async function startAttempt(exam, student, existingAttempt) {
    if(backendEnabled()){
      if(existingAttempt){const resumed=await resumeAttempt(existingAttempt.id,exam.examCode);if(resumed.submission)return {attempt:resumed.attempt,submission:resumed.submission,resumed:false,timedOut:true};return {attempt:resumed.attempt,resumed:true,timedOut:false};}
      let credentials={};try{credentials=JSON.parse(root.sessionStorage.getItem('oopa.backend.verified:'+exam.examCode)||'{}')}catch(_){}
      const data=await backendCall({action:'start',examCode:exam.examCode,verificationToken:credentials.verificationToken||''});
      try{root.sessionStorage.removeItem('oopa.backend.verified:'+exam.examCode)}catch(_){}
      saveToken(data.attempt.id,exam.examCode,data.attemptToken);return {attempt:data.attempt,resumed:!!data.resumed,timedOut:false};
    }
    if (existingAttempt) {
      if (existingAttempt.status !== 'In Progress') throw new Error('This attempt is no longer in progress.');
      if (Date.parse(existingAttempt.deadlineAt) <= Date.now()) { const submission = await submitAttempt(existingAttempt, null, 'Timed Out'); return { attempt: await Store.get('attempts', existingAttempt.id), submission, resumed: false, timedOut: true }; }
      return { attempt: existingAttempt, resumed: true, timedOut: false };
    }
    const availability = examIsAvailable(exam);
    if (!availability.ok) throw new Error(availability.reason);
    const started = Date.now();
    const attempt = Schema.validateAttempt({ id: Schema.makeId('attempt'), examId: exam.id, studentId: student.id,
      studentName: student.name, matricNumber: student.matricNumber, status: 'In Progress', startedAt: new Date(started).toISOString(),
      deadlineAt: new Date(started + Number(exam.durationMinutes) * 60000).toISOString(), submissionId: null,
      labId: exam.labId, examVersion: exam.version || 1, createdAt: new Date(started).toISOString() });
    await Store.put('attempts', attempt);
    await Store.appendAudit(Schema.makeAuditEvent(student.id, 'attempt.start', 'attempt', attempt.id, 'success', { examId: exam.id, examCode: exam.examCode }));
    return { attempt, resumed: false, timedOut: false };
  }
  async function submitAttempt(attempt, evidence, finalStatus) {
    if(backendEnabled()){const session=getToken(attempt.id,attempt.examCode);const data=await backendCall({action:'submit',examCode:session.examCode,attemptId:attempt.id,attemptToken:session.token,evidence:String(evidence==null?(attempt.draftEvidence||''):evidence).slice(0,20000)});removeToken(attempt.id);return data.submission;}
    const current = await Store.get('attempts', attempt.id);
    if (!current) throw new Error('Attempt record not found.');
    if (current.submissionId) return (await Store.get('submissions', current.submissionId));
    if (current.status !== 'In Progress') throw new Error('This attempt has already ended.');
    const timedOut = finalStatus === 'Timed Out' || Date.now() >= Date.parse(current.deadlineAt);
    const status = timedOut ? 'Timed Out' : 'Submitted';
    const submission = { id: Schema.makeId('submission'), attemptId: current.id, examId: current.examId, studentId: current.studentId,
      studentName: current.studentName, matricNumber: current.matricNumber, labId: current.labId,
      evidenceText: String(evidence == null ? (current.draftEvidence || '') : evidence).slice(0, 20000), startedAt: current.startedAt,
      submittedAt: new Date().toISOString(), status, immutable: true, assessmentStatus: 'manual-review-required',
      notes: 'Lab state/evidence is not captured automatically unless a verified lab adapter is implemented.' };
    await Store.put('submissions', submission);
    current.status = status; current.submissionId = submission.id; current.submittedAt = submission.submittedAt; current.updatedAt = submission.submittedAt;
    await Store.put('attempts', current);
    await Store.appendAudit(Schema.makeAuditEvent(current.studentId, status === 'Timed Out' ? 'attempt.timeout-submit' : 'attempt.submit', 'attempt', current.id, 'success', { examId: current.examId, submissionId: submission.id }));
    return submission;
  }
  async function saveEvidence(attempt,evidence){
    if(backendEnabled()){const session=getToken(attempt.id,attempt.examCode);const data=await backendCall({action:'save',examCode:session.examCode,attemptId:attempt.id,attemptToken:session.token,evidence:String(evidence||'').slice(0,20000)});attempt.draftEvidence=String(evidence||'').slice(0,20000);attempt.updatedAt=data.savedAt;return attempt;}
    const fresh=await Store.get('attempts',attempt.id);if(!fresh||fresh.status!=='In Progress')throw new Error('This attempt is no longer in progress.');fresh.draftEvidence=String(evidence||'').slice(0,20000);fresh.updatedAt=new Date().toISOString();await Store.put('attempts',fresh);return fresh;
  }
  async function resumeAttempt(attemptId, examCode) {
    if(backendEnabled()){const session=getToken(attemptId,examCode);const data=await backendCall({action:'resume',examCode:session.examCode,attemptId,attemptToken:session.token});const attempt=data.attempt;attempt.draftEvidence=data.draftEvidence||attempt.draftEvidence||'';if(data.submission)return {attempt,submission:data.submission};if(attempt.status==='In Progress'&&Date.now()>=Date.parse(attempt.deadlineAt)){const submission=await submitAttempt(attempt,attempt.draftEvidence,'Timed Out');return {attempt:Object.assign({},attempt,{status:submission.status,submissionId:submission.id}),submission};}return {attempt,submission:null};}
    const attempt = await Store.get('attempts', attemptId);
    if (!attempt) throw new Error('Saved attempt not found.');
    if (attempt.status !== 'In Progress') return { attempt, submission: attempt.submissionId ? await Store.get('submissions', attempt.submissionId) : null };
    if (Date.now() >= Date.parse(attempt.deadlineAt)) {
      const submission = await submitAttempt(attempt, null, 'Timed Out');
      return { attempt: await Store.get('attempts', attemptId), submission };
    }
    return { attempt, submission: null };
  }
  root.OOPAStudentRuntime = Object.freeze({ verifyAccessCode, examIsAvailable, findPublishedExam, verifyStudent, startAttempt, submitAttempt, saveEvidence, resumeAttempt, backendEnabled });
  if (typeof module !== 'undefined' && module.exports) module.exports = root.OOPAStudentRuntime;
})(typeof globalThis !== 'undefined' ? globalThis : this);
