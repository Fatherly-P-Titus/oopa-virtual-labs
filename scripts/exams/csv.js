/* Small RFC-4180-style CSV helpers for roster/results exchange. */
(function (root) {
  'use strict';
  function parse(text) {
    if (typeof text !== 'string') throw new TypeError('CSV input must be text');
    text = text.replace(/^\uFEFF/, '');
    const rows = []; let row = [], cell = '', quoted = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (quoted) {
        if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
        else if (ch === '"') quoted = false;
        else cell += ch;
      } else if (ch === '"' && cell.length === 0) quoted = true;
      else if (ch === ',') { row.push(cell); cell = ''; }
      else if (ch === '\n' || ch === '\r') {
        if (ch === '\r' && text[i + 1] === '\n') i++;
        row.push(cell); cell = '';
        if (row.some(v => v.trim() !== '')) rows.push(row);
        row = [];
      } else cell += ch;
    }
    if (quoted) throw new Error('CSV contains an unclosed quoted field');
    if (cell.length || row.length) { row.push(cell); if (row.some(v => v.trim() !== '')) rows.push(row); }
    return rows;
  }
  function escapeCell(value, protectSpreadsheet) {
    let text = value == null ? '' : String(value);
    if (protectSpreadsheet !== false && /^[\s]*[=+@\-]/.test(text)) text = "'" + text;
    return /[",\r\n]/.test(text) ? '"' + text.replace(/"/g, '""') + '"' : text;
  }
  function stringify(rows, options) {
    options = options || {};
    if (!Array.isArray(rows)) throw new TypeError('CSV rows must be an array');
    return rows.map(row => {
      if (!Array.isArray(row)) throw new TypeError('Each CSV row must be an array');
      return row.map(cell => escapeCell(cell, options.protectSpreadsheet !== false)).join(',');
    }).join('\r\n') + (rows.length ? '\r\n' : '');
  }
  function parseStudentRoster(text) {
    const rows = parse(text);
    if (!rows.length) return { students: [], errors: [], warnings: ['The CSV file is empty.'] };
    const first = rows[0].map(x => x.trim().toLowerCase());
    let start = 0, nameIndex = 1, matricIndex = 2;
    if (first.includes('student name') && first.includes('matric number')) {
      start = 1; nameIndex = first.indexOf('student name'); matricIndex = first.indexOf('matric number');
    } else if (first.includes('name') && first.includes('matric number')) {
      start = 1; nameIndex = first.indexOf('name'); matricIndex = first.indexOf('matric number');
    }
    const students = [], errors = [], seen = new Set();
    for (let i = start; i < rows.length; i++) {
      const row = rows[i]; const line = i + 1;
      const name = String(row[nameIndex] == null ? '' : row[nameIndex]).trim();
      const matricNumber = String(row[matricIndex] == null ? '' : row[matricIndex]).trim().toUpperCase().replace(/\s+/g, ' ');
      if (!name && !matricNumber) continue;
      if (!name || !matricNumber) { errors.push({ line, message: 'Student name and matric number are both required.' }); continue; }
      if (name.length > 160) { errors.push({ line, message: 'Student name exceeds 160 characters.' }); continue; }
      if (matricNumber.length > 80) { errors.push({ line, message: 'Matric number exceeds 80 characters.' }); continue; }
      if (seen.has(matricNumber)) { errors.push({ line, message: 'Duplicate matric number: ' + matricNumber }); continue; }
      seen.add(matricNumber); students.push({ name, matricNumber });
    }
    return { students, errors, warnings: [] };
  }
  root.OOPAExamCSV = Object.freeze({ parse, stringify, parseStudentRoster });
  if (typeof module !== 'undefined' && module.exports) module.exports = root.OOPAExamCSV;
})(typeof globalThis !== 'undefined' ? globalThis : this);
