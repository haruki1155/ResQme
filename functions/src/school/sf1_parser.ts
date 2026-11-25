import {HttpsError} from 'firebase-functions/v2/https';
import * as XLSX from 'xlsx';

export const MAX_SF1_FILE_BYTES = 2 * 1024 * 1024;
export const MAX_SF1_RAW_ROWS = 2500;
export const MAX_SF1_STUDENTS = 500;
export const MAX_SF1_SHEETS = 20;

export interface ParsedSf1Row {
  rowNumber: number;
  lrn: string | null;
  lastName: string;
  firstName: string;
  middleName: string;
  fullName: string;
  sex: string | null;
  birthDate: string | null;
  gradeLevel: string;
  fatherName: string | null;
  motherMaidenName: string | null;
  guardianName: string | null;
  guardianRelationship: string | null;
  parentGuardianContact: string | null;
  validationError: string | null;
}

export interface ParsedSf1Workbook {
  sheetName: string;
  detectedGradeLevel: string | null;
  effectiveGradeLevel: string;
  schoolName: string | null;
  schoolYear: string | null;
  section: string | null;
  rows: ParsedSf1Row[];
}

function cleanText(raw: unknown): string {
  if (raw == null) return '';
  return String(raw).replace(/\s+/g, ' ').trim();
}

function normalizeHeaderText(raw: unknown): string {
  return cleanText(raw).toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function isFooterOrSummaryRow(cells: string[]): boolean {
  const joined = cells.map((c) => c.toLowerCase()).join(' ');
  if (!joined.trim()) return false;
  return (
    joined.includes('list and code of indicators') ||
    joined.includes('prepared by') ||
    joined.includes('certified correct') ||
    joined.includes('signature of adviser') ||
    joined.includes('signature of school head') ||
    joined.includes('registered') && joined.includes('bosy')
  );
}

function splitNameParts(raw: string): {
  lastName: string;
  firstName: string;
  middleName: string;
  fullName: string;
} {
  const cleaned = cleanText(raw);
  if (!cleaned) {
    return {lastName: '', firstName: '', middleName: '', fullName: ''};
  }
  const commaParts = cleaned.split(',').map((p) => p.trim()).filter(Boolean);
  if (commaParts.length >= 2) {
    const lastName = commaParts[0];
    let firstName = '';
    let middleName = '';
    if (commaParts.length >= 3) {
      firstName = commaParts[1];
      middleName = commaParts.slice(2).join(' ');
    } else {
      const restTokens = commaParts[1].split(/\s+/).filter(Boolean);
      if (restTokens.length >= 2) {
        middleName = restTokens[restTokens.length - 1];
        firstName = restTokens.slice(0, -1).join(' ');
      } else {
        firstName = restTokens[0] ?? '';
      }
    }
    const fullName = [firstName, middleName, lastName].filter(Boolean).join(' ');
    return {lastName, firstName, middleName, fullName};
  }
  const tokens = cleaned.split(/\s+/).filter(Boolean);
  if (tokens.length === 1) {
    return {lastName: tokens[0], firstName: tokens[0], middleName: '', fullName: tokens[0]};
  }
  const firstName = tokens[0];
  const lastName = tokens[tokens.length - 1];
  const middleName = tokens.length > 2 ? tokens.slice(1, -1).join(' ') : '';
  return {
    lastName,
    firstName,
    middleName,
    fullName: [firstName, middleName, lastName].filter(Boolean).join(' '),
  };
}

function normalizeSex(raw: string): string | null {
  const v = raw.trim().toLowerCase();
  if (!v) return null;
  if (v === 'm' || v === 'male') return 'Male';
  if (v === 'f' || v === 'female') return 'Female';
  return '__invalid__';
}

function isValidCalendarDate(year: number, month: number, day: number): boolean {
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) {
    return false;
  }
  if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) {
    return false;
  }
  const d = new Date(Date.UTC(year, month - 1, day));
  return (
    d.getUTCFullYear() === year &&
    d.getUTCMonth() === month - 1 &&
    d.getUTCDate() === day
  );
}

function formatIsoDate(year: number, month: number, day: number): string {
  return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

export function parseStrictExcelDate(cell: XLSX.CellObject | undefined): {
  iso: string | null;
  invalid: boolean;
} {
  if (!cell || cell.v == null || cleanText(cell.w ?? cell.v) === '') {
    return {iso: null, invalid: false};
  }
  if (cell.v instanceof Date && Number.isFinite(cell.v.getTime())) {
    const shifted = new Date(cell.v.getTime() + 12 * 3600 * 1000);
    const y = shifted.getUTCFullYear();
    const m = shifted.getUTCMonth() + 1;
    const d = shifted.getUTCDate();
    return isValidCalendarDate(y, m, d)
      ? {iso: formatIsoDate(y, m, d), invalid: false}
      : {iso: null, invalid: true};
  }
  if (typeof cell.v === 'number' && Number.isFinite(cell.v)) {
    const parsed = XLSX.SSF.parse_date_code(cell.v);
    if (parsed && isValidCalendarDate(parsed.y, parsed.m, parsed.d)) {
      return {iso: formatIsoDate(parsed.y, parsed.m, parsed.d), invalid: false};
    }
    return {iso: null, invalid: true};
  }
  const text = cleanText(cell.w ?? cell.v);
  const isoMatch = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(text);
  if (isoMatch) {
    const y = Number(isoMatch[1]);
    const m = Number(isoMatch[2]);
    const d = Number(isoMatch[3]);
    return isValidCalendarDate(y, m, d)
      ? {iso: formatIsoDate(y, m, d), invalid: false}
      : {iso: null, invalid: true};
  }
  const mdyMatch = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(text);
  if (mdyMatch) {
    const m = Number(mdyMatch[1]);
    const d = Number(mdyMatch[2]);
    const y = Number(mdyMatch[3]);
    return isValidCalendarDate(y, m, d)
      ? {iso: formatIsoDate(y, m, d), invalid: false}
      : {iso: null, invalid: true};
  }
  return {iso: null, invalid: true};
}

function extractLrnFromCell(cell: XLSX.CellObject | undefined): string | null {
  if (!cell || cell.v == null) return null;
  const formatted = typeof cell.w === 'string' ? cell.w.trim() : '';
  const candidate = (formatted && !/[eE+]/.test(formatted) ? formatted : String(cell.v))
    .replace(/[\s-]/g, '')
    .trim();
  if (/^\d{12}$/.test(candidate)) return candidate;
  return null;
}

function cellText(ws: XLSX.WorkSheet, r: number, c: number): string {
  const addr = XLSX.utils.encode_cell({r, c});
  const cell = ws[addr] as XLSX.CellObject | undefined;
  if (!cell || cell.v == null) return '';
  return cleanText(cell.w ?? cell.v);
}

function extractMetadataValue(
  ws: XLSX.WorkSheet,
  maxRow: number,
  maxCol: number,
  labelPattern: RegExp,
): string | null {
  for (let r = 0; r < maxRow; r++) {
    for (let c = 0; c < maxCol; c++) {
      const txt = cellText(ws, r, c);
      if (labelPattern.test(txt)) {
        for (let dc = 1; dc <= 4 && c + dc < maxCol; dc++) {
          const v = cellText(ws, r, c + dc);
          if (v && !/^(school id|division|district|school name|school year|grade level|section)$/i.test(v)) {
            return v;
          }
        }
      }
    }
  }
  return null;
}

export function parseSf1Workbook(input: {
  buffer: Buffer;
  confirmedGradeLevel?: string | null;
}): ParsedSf1Workbook {
  if (!Buffer.isBuffer(input.buffer) || input.buffer.length === 0) {
    throw new HttpsError('invalid-argument', 'Uploaded spreadsheet file is empty.');
  }
  if (input.buffer.length > MAX_SF1_FILE_BYTES) {
    throw new HttpsError('invalid-argument', 'Spreadsheet file exceeds the 2 MB limit.');
  }

  let wb: XLSX.WorkBook;
  try {
    wb = XLSX.read(input.buffer, {
      type: 'buffer',
      cellDates: true,
      cellNF: true,
      cellFormula: false,
      cellHTML: false,
      sheetStubs: false,
      raw: false,
    });
  } catch {
    throw new HttpsError('invalid-argument', 'Unable to read Excel file. Upload a valid .xls or .xlsx SF1 workbook.');
  }

  if (!wb.SheetNames || wb.SheetNames.length === 0) {
    throw new HttpsError('invalid-argument', 'Spreadsheet contains no worksheets.');
  }
  if (wb.SheetNames.length > MAX_SF1_SHEETS) {
    throw new HttpsError('invalid-argument', `Spreadsheet exceeds maximum ${MAX_SF1_SHEETS} worksheets.`);
  }

  let targetSheetName: string | null = null;
  let headerRow = -1;
  let lrnCol = -1;
  let nameCol = -1;
  let sexCol = -1;
  let birthCol = -1;
  let fatherCol = -1;
  let motherCol = -1;
  let guardianNameCol = -1;
  let guardianRelCol = -1;
  let contactCol = -1;

  for (const name of wb.SheetNames) {
    const ws = wb.Sheets[name];
    if (!ws || !ws['!ref']) continue;
    const range = XLSX.utils.decode_range(ws['!ref']);
    if (range.e.r - range.s.r + 1 > MAX_SF1_RAW_ROWS) {
      throw new HttpsError('invalid-argument', 'Spreadsheet exceeds maximum supported row count (2,500 rows).');
    }

    const scanLimit = Math.min(range.e.r, 30);
    for (let r = range.s.r; r <= scanLimit; r++) {
      let foundLrn = -1;
      let foundName = -1;
      let foundSex = -1;
      let foundBirth = -1;
      let foundContact = -1;
      let foundGuardianGroup = -1;

      for (let c = range.s.c; c <= range.e.c; c++) {
        const norm = normalizeHeaderText(cellText(ws, r, c));
        if (!norm) continue;
        if (foundLrn === -1 && norm === 'lrn') foundLrn = c;
        else if (foundName === -1 && (norm === 'name' || norm.startsWith('name last name'))) foundName = c;
        else if (foundSex === -1 && (norm === 'sex' || norm.startsWith('sex m f'))) foundSex = c;
        else if (foundBirth === -1 && norm.startsWith('birth date')) foundBirth = c;
        else if (foundContact === -1 && norm.includes('contact number')) foundContact = c;
        else if (foundGuardianGroup === -1 && norm.startsWith('guardian')) foundGuardianGroup = c;
      }

      if (foundLrn !== -1 && foundName !== -1 && foundBirth !== -1) {
        targetSheetName = name;
        headerRow = r;
        lrnCol = foundLrn;
        nameCol = foundName;
        sexCol = foundSex;
        birthCol = foundBirth;
        contactCol = foundContact;

        // Scan subheader row (r + 1) if present
        if (r + 1 <= range.e.r) {
          for (let c = range.s.c; c <= range.e.c; c++) {
            const sub = normalizeHeaderText(cellText(ws, r + 1, c));
            if (!sub) continue;
            if (fatherCol === -1 && sub.startsWith('father s name')) fatherCol = c;
            else if (motherCol === -1 && sub.startsWith('mother s maiden name')) motherCol = c;
            else if (guardianNameCol === -1 && sub === 'name' && (foundGuardianGroup === -1 || c >= foundGuardianGroup)) guardianNameCol = c;
            else if (guardianRelCol === -1 && (sub === 'relation ship' || sub === 'relationship')) guardianRelCol = c;
          }
        }
        break;
      }
    }
    if (targetSheetName) break;
  }

  if (!targetSheetName || headerRow === -1) {
    throw new HttpsError(
      'invalid-argument',
      'Missing required SF1 header columns (LRN, NAME, BIRTH DATE).',
    );
  }

  const ws = wb.Sheets[targetSheetName];
  const range = XLSX.utils.decode_range(ws['!ref']!);
  const maxCol = range.e.c + 1;

  const detectedGradeLevel = extractMetadataValue(ws, headerRow, maxCol, /^grade level$/i);
  const schoolName = extractMetadataValue(ws, headerRow, maxCol, /^school name$/i);
  const schoolYear = extractMetadataValue(ws, headerRow, maxCol, /^school year$/i);
  const section = extractMetadataValue(ws, headerRow, maxCol, /^section$/i);

  const confirmed = cleanText(input.confirmedGradeLevel ?? '');
  const effectiveGradeLevel = confirmed || detectedGradeLevel || '';
  if (!effectiveGradeLevel) {
    throw new HttpsError(
      'invalid-argument',
      'Grade level could not be detected from the SF1 sheet. Confirm the grade level before importing.',
    );
  }

  const dataStartRow = fatherCol !== -1 || motherCol !== -1 || guardianNameCol !== -1 ? headerRow + 2 : headerRow + 1;
  const parsedRows: ParsedSf1Row[] = [];

  for (let r = dataStartRow; r <= range.e.r; r++) {
    const rowStrings: string[] = [];
    for (let c = range.s.c; c <= range.e.c; c++) {
      rowStrings.push(cellText(ws, r, c));
    }
    if (isFooterOrSummaryRow(rowStrings)) break;

    const lrnAddr = XLSX.utils.encode_cell({r, c: lrnCol});
    const lrnCell = ws[lrnAddr] as XLSX.CellObject | undefined;
    const rawLrnText = cellText(ws, r, lrnCol);
    const rawName = cellText(ws, r, nameCol);

    if (!rawLrnText && !rawName) continue;
    if (normalizeHeaderText(rawLrnText) === 'lrn' || normalizeHeaderText(rawName).startsWith('last name')) continue;

    if (parsedRows.length >= MAX_SF1_STUDENTS) {
      throw new HttpsError('invalid-argument', `Import exceeds the maximum ${MAX_SF1_STUDENTS} student rows per file.`);
    }

    const lrn = extractLrnFromCell(lrnCell);
    const nameParts = splitNameParts(rawName);
    const rawSex = sexCol !== -1 ? cellText(ws, r, sexCol) : '';
    const sex = normalizeSex(rawSex);
    const birthCell = ws[XLSX.utils.encode_cell({r, c: birthCol})] as XLSX.CellObject | undefined;
    const birth = parseStrictExcelDate(birthCell);

    const errors: string[] = [];
    if (!lrn) errors.push('Invalid or missing 12-digit LRN');
    if (!nameParts.fullName || !nameParts.lastName || !nameParts.firstName) {
      errors.push('Missing student Last/First Name');
    }
    if (sex === '__invalid__') errors.push('Invalid sex value (expected M/F)');
    if (birth.invalid || !birth.iso) errors.push('Invalid or missing birth date');

    parsedRows.push({
      rowNumber: r + 1,
      lrn,
      lastName: nameParts.lastName,
      firstName: nameParts.firstName,
      middleName: nameParts.middleName,
      fullName: nameParts.fullName,
      sex: sex === '__invalid__' ? null : sex,
      birthDate: birth.iso,
      gradeLevel: effectiveGradeLevel,
      fatherName: fatherCol !== -1 ? cleanText(cellText(ws, r, fatherCol)) || null : null,
      motherMaidenName: motherCol !== -1 ? cleanText(cellText(ws, r, motherCol)) || null : null,
      guardianName: guardianNameCol !== -1 ? cleanText(cellText(ws, r, guardianNameCol)) || null : null,
      guardianRelationship: guardianRelCol !== -1 ? cleanText(cellText(ws, r, guardianRelCol)) || null : null,
      parentGuardianContact: contactCol !== -1 ? cleanText(cellText(ws, r, contactCol)) || null : null,
      validationError: errors.length > 0 ? errors.join('; ') : null,
    });
  }

  if (parsedRows.length === 0) {
    throw new HttpsError('invalid-argument', 'No student rows were found in the SF1 worksheet.');
  }

  return {
    sheetName: targetSheetName,
    detectedGradeLevel,
    effectiveGradeLevel,
    schoolName,
    schoolYear,
    section,
    rows: parsedRows,
  };
}
