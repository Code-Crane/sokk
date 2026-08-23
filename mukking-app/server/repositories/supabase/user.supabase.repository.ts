import type { MannerGrade, UserAccount } from "../../../shared/types";
import { DEFAULT_MANNER_SCORE, getMannerGrade } from "../../../shared/utils/rating";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import type { UserRepository } from "../interfaces/user.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type Row = { user_id:string; email:string; nickname:string; phone_number:string; verification_status:UserAccount["verificationStatus"]; account_status:"active"|"suspended"|"banned"; created_at:string };
const toUser = async (row: Row): Promise<UserAccount> => {
  const { data } = await getSupabaseServiceRoleClient().from("user_manner_profiles").select("manner_score,manner_grade").eq("user_id", row.user_id).maybeSingle<{manner_score:number;manner_grade:MannerGrade}>();
  const score = data ? Number(data.manner_score) : DEFAULT_MANNER_SCORE;
  return { id:row.user_id, email:row.email, nickname:row.nickname, phoneNumber:row.phone_number, verificationStatus:row.verification_status, mannerScore:score, mannerGrade:data?.manner_grade ?? getMannerGrade(score), createdAt:row.created_at };
};
async function getRow(userId:string) { const {data,error}=await getSupabaseServiceRoleClient().from("user_profiles").select("*").eq("user_id",userId).maybeSingle<Row>(); if(error) throwSupabaseError(error); return data; }

export const supabaseUserRepository: UserRepository = {
  async findById(id){ const row=await getRow(id); return row ? toUser(row) : null; },
  async findByEmail(email){ const {data,error}=await getSupabaseServiceRoleClient().from("user_profiles").select("*").ilike("email",email).maybeSingle<Row>(); if(error) throwSupabaseError(error); return data ? toUser(data) : null; },
  async create(input){ const score=input.mannerScore ?? DEFAULT_MANNER_SCORE; const {data,error}=await getSupabaseServiceRoleClient().from("user_profiles").upsert({user_id:input.id,email:input.email,nickname:input.nickname,phone_number:input.phoneNumber,verification_status:input.verificationStatus ?? "unverified",created_at:input.createdAt},{onConflict:"user_id"}).select("*").single<Row>(); if(error) throwSupabaseError(error); if(input.id){ const profile=await getSupabaseServiceRoleClient().from("user_manner_profiles").upsert({user_id:input.id,manner_score:score,manner_grade:input.mannerGrade ?? getMannerGrade(score)}); if(profile.error) throwSupabaseError(profile.error); } return toUser(ensureRow(data,"User profile was not created.")); },
  async update(id,input){ const patch:Record<string,unknown>={}; if(input.nickname!==undefined)patch.nickname=input.nickname; if(input.phoneNumber!==undefined)patch.phone_number=input.phoneNumber; if(input.verificationStatus!==undefined)patch.verification_status=input.verificationStatus; if(input.accountStatus!==undefined)patch.account_status=input.accountStatus; const {data,error}=await getSupabaseServiceRoleClient().from("user_profiles").update(patch).eq("user_id",id).select("*").single<Row>(); if(error) throwSupabaseError(error); if(input.mannerScore!==undefined||input.mannerGrade!==undefined){ const current=await this.findById(id); const score=input.mannerScore ?? current?.mannerScore ?? DEFAULT_MANNER_SCORE; const result=await getSupabaseServiceRoleClient().from("user_manner_profiles").upsert({user_id:id,manner_score:score,manner_grade:input.mannerGrade ?? getMannerGrade(score)}); if(result.error)throwSupabaseError(result.error); } return toUser(ensureRow(data,"User profile not found.")); },
  async setVerificationStatus(id,status){ return this.update(id,{verificationStatus:status}); },
  async updateMannerProfile(id,score,grade){ const result=await getSupabaseServiceRoleClient().from("user_manner_profiles").upsert({user_id:id,manner_score:score,manner_grade:grade}); if(result.error)throwSupabaseError(result.error); const user=await this.findById(id); return ensureRow(user,"User profile not found."); },
  async setAccountStatus(id,status){ return this.update(id,{accountStatus:status}); },
  toPublicProfile(user,pending){ return {...user,pendingEvaluationCount:pending}; },
  async listForAdmin(){ const {data,error}=await getSupabaseServiceRoleClient().from("user_profiles").select("*").order("created_at",{ascending:false}).returns<Row[]>(); if(error)throwSupabaseError(error); return Promise.all((data??[]).map(async row=>({...this.toPublicProfile(await toUser(row),0),accountStatus:row.account_status,activeSanctionCount:0,reportCount:0}))); }
};
