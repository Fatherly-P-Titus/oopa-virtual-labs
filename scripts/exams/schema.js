/* OOPA examination foundation: shared identifiers, validation and record factories.
 * Browser global: OOPAExamSchema. No lab UI is modified by this module.
 */
(function (root) {
  'use strict';
  const SCHEMA_VERSION = 2;
  const COLLECTIONS = Object.freeze([
    'administrators', 'instructors', 'hubs', 'studentLists', 'students', 'exams',
    'eligibilitySnapshots', 'attempts', 'submissions', 'grades', 'auditEvents'
  ]);
  const EXAM_STATUSES = Object.freeze(['Draft', 'Published', 'Closed', 'Archived']);
  const ATTEMPT_STATUSES = Object.freeze(['Not Started', 'In Progress', 'Submitted', 'Timed Out', 'Cancelled', 'Invalidated']);

  function makeId(prefix) {
    const uuid = root.crypto && typeof root.crypto.randomUUID === 'function'
      ? root.crypto.randomUUID()
      : (Date.now().toString(36) + '-' + Math.random().toString(36).slice(2) + '-' + Math.random().toString(36).slice(2));
    return String(prefix || 'rec') + '_' + uuid;
  }
  function cleanString(value, field, maxLength, required) {
    if (typeof value !== 'string') throw new TypeError(field + ' must be a string');
    const result = value.trim();
    if (required && !result) throw new Error(field + ' is required');
    if (maxLength && result.length > maxLength) throw new Error(field + ' exceeds ' + maxLength + ' characters');
    return result;
  }
  function validateAccessCode(value) {
    const code = String(value == null ? '' : value);
    if (!/^\d{6}$/.test(code)) throw new Error('Access code must contain exactly six digits');
    return code;
  }
  function normalizeMatric(value) {
    return cleanString(String(value == null ? '' : value), 'Matric number', 80, true).toUpperCase().replace(/\s+/g, ' ');
  }
  function validateStudent(student) {
    if (!student || typeof student !== 'object') throw new TypeError('Student record must be an object');
    return {
      id: student.id || makeId('stu'),
      name: cleanString(student.name, 'Student name', 160, true),
      matricNumber: normalizeMatric(student.matricNumber),
      createdAt: student.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
  }
  function validateExam(exam) {
    if (!exam || typeof exam !== 'object') throw new TypeError('Exam record must be an object');
    const title = cleanString(exam.title, 'Exam title', 180, true);
    const durationMinutes = Number(exam.durationMinutes);
    if (!Number.isInteger(durationMinutes) || durationMinutes < 5 || durationMinutes > 60 || durationMinutes % 5 !== 0) {
      throw new Error('Exam duration must be 5–60 minutes in 5-minute increments');
    }
    const status = exam.status || 'Draft';
    if (!EXAM_STATUSES.includes(status)) throw new Error('Invalid exam status');
    const attemptLimit = exam.attemptLimit == null ? 1 : Number(exam.attemptLimit);
    if (!Number.isInteger(attemptLimit) || attemptLimit < 1 || attemptLimit > 10) throw new Error('Attempt limit must be an integer from 1 to 10');
    const accessCodeHash = cleanString(exam.accessCodeHash || '', 'Access-code verifier', 512, true);
    if (!/^[A-Za-z0-9:_$.-]{16,512}$/.test(accessCodeHash)) throw new Error('Access-code verifier has an invalid format');
    if (!cleanString(exam.labId, 'Lab ID', 120, true)) throw new Error('Lab ID is required');
    if (!cleanString(exam.ownerInstructorId, 'Owner instructor ID', 160, true)) throw new Error('Owner instructor ID is required');
    return {
      id: exam.id || makeId('exam'),
      examCode: exam.examCode || makeId('EXAM').toUpperCase(),
      title, labId: exam.labId.trim(), hubId: cleanString(exam.hubId || 'unassigned', 'Hub ID', 120, true),
      ownerInstructorId: exam.ownerInstructorId.trim(), durationMinutes, accessCodeHash,
      status, attemptLimit,
      availableFrom: exam.availableFrom || null,
      availableUntil: exam.availableUntil || null,
      instructions: cleanString(exam.instructions || '', 'Instructions', 10000, false),
      resultsPolicy: exam.resultsPolicy || 'after-release',
      studentListId: exam.studentListId || null,
      resultsReleasedAt: exam.resultsReleasedAt || null,
      resultsReleasedBy: exam.resultsReleasedBy || null,
      createdAt: exam.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      version: Number.isInteger(exam.version) && exam.version > 0 ? exam.version : 1
    };
  }
  function validateAttempt(attempt) {
    if (!attempt || typeof attempt !== 'object') throw new TypeError('Attempt record must be an object');
    const status = attempt.status || 'Not Started';
    if (!ATTEMPT_STATUSES.includes(status)) throw new Error('Invalid attempt status');
    if (!attempt.examId || !attempt.studentId) throw new Error('Attempt requires examId and studentId');
    const startedAt = attempt.startedAt || null;
    const deadlineAt = attempt.deadlineAt || null;
    if (startedAt && !Number.isFinite(Date.parse(startedAt))) throw new Error('Invalid attempt start timestamp');
    if (deadlineAt && !Number.isFinite(Date.parse(deadlineAt))) throw new Error('Invalid attempt deadline timestamp');
    if (startedAt && deadlineAt && Date.parse(deadlineAt) < Date.parse(startedAt)) throw new Error('Attempt deadline cannot precede its start');
    return Object.assign({}, attempt, {
      id: attempt.id || makeId('attempt'), status,
      startedAt, deadlineAt,
      createdAt: attempt.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
  }
  function validateRecord(collection, record) {
    if (!COLLECTIONS.includes(collection)) throw new Error('Unknown collection: ' + collection);
    if (!record || typeof record !== 'object' || Array.isArray(record)) throw new TypeError('Record must be an object');
    if (collection === 'students') return validateStudent(record);
    if (collection === 'exams') return validateExam(record);
    if (collection === 'attempts') return validateAttempt(record);
    const copy = Object.assign({}, record);
    if (!copy.id) copy.id = makeId(collection.replace(/s$/, '') || 'rec');
    if (!copy.createdAt) copy.createdAt = new Date().toISOString();
    copy.updatedAt = new Date().toISOString();
    return copy;
  }
  function canTransitionExam(from, to) {
    const allowed = { Draft: ['Published'], Published: ['Closed'], Closed: ['Archived'], Archived: [] };
    return !!(allowed[from] && allowed[from].includes(to));
  }
  function canTransitionAttempt(from, to) {
    const allowed = {
      'Not Started': ['In Progress', 'Cancelled'],
      'In Progress': ['Submitted', 'Timed Out', 'Cancelled', 'Invalidated'],
      'Submitted': ['Invalidated'], 'Timed Out': ['Invalidated'], 'Cancelled': [], 'Invalidated': []
    };
    return !!(allowed[from] && allowed[from].includes(to));
  }
  function makeAuditEvent(actorId, action, entityType, entityId, outcome, details) {
    return {
      id: makeId('audit'), actorId: actorId || 'system', action: cleanString(action, 'Audit action', 120, true),
      entityType: cleanString(entityType, 'Entity type', 80, true), entityId: entityId || null,
      outcome: outcome || 'success', details: details && typeof details === 'object' ? details : {},
      occurredAt: new Date().toISOString(), schemaVersion: SCHEMA_VERSION
    };
  }
  root.OOPAExamSchema = Object.freeze({ SCHEMA_VERSION, COLLECTIONS, EXAM_STATUSES, ATTEMPT_STATUSES, makeId, validateAccessCode, normalizeMatric, validateStudent, validateExam, validateAttempt, validateRecord, canTransitionExam, canTransitionAttempt, makeAuditEvent });
  if (typeof module !== 'undefined' && module.exports) module.exports = root.OOPAExamSchema;
})(typeof globalThis !== 'undefined' ? globalThis : this);
