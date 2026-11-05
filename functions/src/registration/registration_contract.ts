export const noticeVersion = 'tier1-registration-v1';
export type RegistrationInput = {fullName:string;ageYears:number;noticeVersion:string;acknowledgmentAccepted:boolean;status?:unknown;lrn?:unknown;gender?:unknown;personalPhone?:unknown;guardianName?:unknown;guardianRelationship?:unknown;guardianPhone?:unknown;secondaryName?:unknown;secondaryPhone?:unknown};
function optionalText(value: unknown, max = 120): string | null {
  if (value == null) return null;
  if (typeof value !== 'string' || value.trim().length > max) throw new Error('profile');
  return value.trim() || null;
}
function name(value: unknown): string | null {
  const result = optionalText(value);
  if (result && result.length < 2) throw new Error('profile');
  return result;
}
function phone(value: unknown): string | null {
  const result = optionalText(value, 32)?.replace(/[ -]/g, '') ?? null;
  if (result && !/^(09\d{9}|\+639\d{9})$/.test(result)) throw new Error('phone');
  return result;
}
export function validateRegistration(input: RegistrationInput) {
  if(input.noticeVersion!==noticeVersion||input.acknowledgmentAccepted!==true) throw new Error('acknowledgment');
  const fullName = name(input.fullName);
  if (!fullName || !Number.isInteger(input.ageYears) || input.ageYears<0 || input.ageYears>130) throw new Error('profile');
  const secondaryName = name(input.secondaryName);
  const secondaryPhone = phone(input.secondaryPhone);
  if (Boolean(secondaryName) !== Boolean(secondaryPhone)) throw new Error('secondary');
  return {fullName, ageYears:input.ageYears, status:input.ageYears<18?'pending_guardian':'pending_review', lrn:null,
    gender:optionalText(input.gender, 40), personalContactNumber:phone(input.personalPhone),
    emergencyContacts:{primary:{fullName:name(input.guardianName), relationship:optionalText(input.guardianRelationship, 40), phoneNumber:phone(input.guardianPhone)}, secondary:{fullName:secondaryName, phoneNumber:secondaryPhone}}};
}
