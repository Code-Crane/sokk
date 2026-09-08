// Explicit manual live smoke. Creates ONLY disposable accounts; never modifies A/B.
const crypto = require("crypto");
require("dotenv").config();
process.env.AUTH_PROVIDER="supabase";
process.env.REPOSITORY_PROVIDER="supabase";
const {createClient}=require("@supabase/supabase-js");
const {app}=require("../dist/server/app");
const {awardPetXpBestEffort}=require("../dist/server/services/pet/pet.service");
const {xpForLevel}=require("../dist/shared/utils/pet");
const marker="[TEST][PET_LIVE:"+crypto.randomUUID()+"]";
const service=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const users=[]; let postId; let server; let step="startup";
function check(ok,label){step=label;if(!ok)throw Error(label);console.log("[PET_LIVE] PASS "+label);}
async function cleanQuery(query){const r=await query;if(r.error)throw Error("cleanup query failed");}
async function main(){
 server=await new Promise(resolve=>{const s=app.listen(0,"127.0.0.1",()=>resolve(s));});
 const base="http://127.0.0.1:"+server.address().port;
 async function api(path,user,body){
  const r=await fetch(base+path,{method:body===undefined?"GET":"POST",headers:{"Content-Type":"application/json",...(user?{Authorization:"Bearer "+user.token}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  return {status:r.status,data:await r.json().catch(()=>null)};
 }
 try {
  for(const type of ["healthy","night","hearty"]){
   step="temporary "+type+" account";
   const email="pet-live-"+crypto.randomUUID()+"@example.com";
   const password=crypto.randomBytes(28).toString("base64url")+"a1!";
   const created=await service.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{nickname:marker}});
   if(created.error||!created.data.user)throw Error(step);
   const user={id:created.data.user.id};users.push(user);
   const auth=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
   const login=await auth.auth.signInWithPassword({email,password});
   if(login.error)throw Error("temporary login");user.token=login.data.session.access_token;
   check((await api("/api/auth/me",user)).status===200,"temporary profile "+type);
   check((await api("/api/pets/me",user)).data===null,"no pet "+type);
   const selected=await api("/api/pets/me",user,{petType:type});
   check(selected.status===201&&selected.data.petType===type,"select "+type);
   check((await api("/api/pets/me",user)).data.id===selected.data.id,"reload "+type);
   check((await api("/api/pets/me",user,{petType:type})).status===409,"duplicate selection "+type);
  }
  const [host,guest,fixture]=users;
  check((await api("/api/pets/me?userId="+host.id,guest)).data.userId===guest.id,"authenticated account isolation");
  check((await service.from("user_pets").update({pet_type:"invalid"}).eq("user_id",fixture.id)).error?.code==="23514","DB invalid pet CHECK");
  check((await service.from("user_pets").insert({user_id:fixture.id,pet_type:"night"})).error?.code==="23505","DB unique user pet");
  check((await service.from("user_pets").update({xp:-1}).eq("user_id",fixture.id)).error?.code==="23514","DB nonnegative XP");
  const event={user_id:fixture.id,source_type:"matching_completed",source_id:marker+":raw",xp_amount:30};
  check(!(await service.from("pet_xp_events").insert(event)).error,"DB event insert");
  check((await service.from("pet_xp_events").insert(event)).error?.code==="23505","DB duplicate event denied");
  check(!(await service.from("pet_xp_events").insert({...event,source_id:marker+":raw2"})).error,"DB distinct source accepted");
  // Raw constraint fixtures belong only to the disposable third account.
  for(const user of [host,guest]){
   check((await api("/api/auth/verification/mock",user,{legalName:"먹킹테스터",birthDate:"1995-01-01",gender:"other",phoneNumber:"01012345678"})).status===200,"temporary matching eligibility");
  }
  const post=await api("/api/matching/posts",host,{restaurantName:marker,address:"테스트",scheduledAt:new Date(Date.now()+86400000).toISOString(),maxParticipants:1,intro:marker});
  check(post.status===201,"real matching create");postId=post.data.id;
  const join=await api("/api/matching/posts/"+postId+"/requests",guest,{});
  check(join.status===201,"real matching join");
  check((await api("/api/matching/requests/"+join.data.id+"/respond",host,{decision:"accepted"})).status===200,"real matching approve");
  check((await api("/api/matching/posts/"+postId+"/complete",host,{})).status===200,"real matching complete");
  check((await api("/api/pets/me",host)).data.xp===50&&(await api("/api/pets/me",guest)).data.xp===30,"completion XP host50 guest30");
  await awardPetXpBestEffort(host.id,"hosted_matching_completed",postId);
  check((await api("/api/pets/me",host)).data.xp===50,"same domain event replay no extra XP");
  check((await api("/api/rating/reviews",host,{matchId:postId,revieweeId:guest.id,score:5,tags:[]})).status===201,"real manner rating");
  check((await api("/api/pets/me",host)).data.xp===65,"rating XP15");
  const ledger=await service.from("pet_xp_events").select("id").eq("user_id",host.id);
  check(!ledger.error&&ledger.data.length===2,"host ledger contains two real events");
  let total=0,previous=0;
  for(let level=1;level<=30;level++){
   if(level>1)total+=xpForLevel(level-1);
   if(![1,4,5,9,10,19,20,29,30].includes(level))continue;
   if(total>previous){
    const award=await service.rpc("award_pet_xp",{p_user_id:fixture.id,p_source_type:"matching_completed",p_source_id:marker+":level"+level,p_amount:total-previous});
    check(!award.error&&award.data===true,"fixture atomic award level"+level);
   }
   previous=total;
   const pet=(await api("/api/pets/me",fixture)).data;
   const expected=level<5?"꼬마":level<10?"새싹 친구":level<20?"단골 친구":level<30?"식탁 친구":"먹킹 마스터";
   check(pet.level===level&&pet.growthStage===expected,"live level/growth "+level);
  }
  const replay=await service.rpc("award_pet_xp",{p_user_id:fixture.id,p_source_type:"matching_completed",p_source_id:marker+":level30",p_amount:1});
  check(!replay.error&&replay.data===false,"SQL RPC dedup");
  const anon=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_ANON_KEY);
  check(Boolean((await anon.rpc("award_pet_xp",{p_user_id:host.id,p_source_type:"matching_completed",p_source_id:"denied",p_amount:30})).error),"public cannot award XP");
 } finally {
  console.log("[PET_LIVE] CLEANUP TARGET "+JSON.stringify({marker,userIds:users.map(u=>u.id),postId}));
  if(postId){
   // Only this run's exact post and users, never name-wide deletes.
   for(const table of ["notifications","manner_ratings","pending_evaluations","chat_rooms"]){
    await cleanQuery(service.from(table).delete().eq("matching_post_id",postId));
   }
   await cleanQuery(service.from("matching_posts").delete().eq("id",postId).eq("intro",marker));
  }
  for(const u of users){
   await cleanQuery(service.from("pet_xp_events").delete().eq("user_id",u.id));
   await cleanQuery(service.from("user_pets").delete().eq("user_id",u.id));
   await cleanQuery(service.from("user_manner_profiles").delete().eq("user_id",u.id));
   const deleted=await service.auth.admin.deleteUser(u.id);
   if(deleted.error)throw Error("temporary user cleanup failed");
  }
  for(const table of ["user_pets","pet_xp_events"]){
   if(users.length){
    const remaining=await service.from(table).select("id",{count:"exact",head:true}).in("user_id",users.map(u=>u.id));
    check(!remaining.error&&remaining.count===0,"cleanup zero "+table);
   }
  }
  await new Promise(resolve=>server.close(resolve));
 }
}
main().catch(()=>{console.error("[PET_LIVE] FAIL at "+step+"; no credentials logged");process.exitCode=1;if(server)server.close();});
