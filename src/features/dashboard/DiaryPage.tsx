import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { BookOpen, CalendarDays, Check, ChevronRight, Pencil, Plus, Save, Trash2, X } from 'lucide-react'
import { supabase } from '../../lib/supabase/client'

type DiaryRole = 'PARENT' | 'CHILD'
type DiaryChild = { id:string; display_name:string; avatar:string }
type DiaryPrompt = { id:string; family_id:string; question:string; position:number; created_at:string }
type DiaryAnswer = { prompt_id:string|null; question:string; answer:string }
type DiaryEntry = { id:string; family_id:string; child_id:string; entry_date:string; answers:DiaryAnswer[]; created_at:string; updated_at:string }

const dateInMexico = () => new Intl.DateTimeFormat('en-CA',{timeZone:'America/Mexico_City',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date())
const isoNow = () => new Date().toISOString()
const formatDate = (value:string, options:Intl.DateTimeFormatOptions={weekday:'long',day:'numeric',month:'long',year:'numeric'}) => {
  const [year,month,day]=value.split('-').map(Number)
  return new Intl.DateTimeFormat('es-MX',options).format(new Date(year,month-1,day,12))
}

export function DiaryPage({role,familyId,profileId,kids}:{role:DiaryRole;familyId:string;profileId:string;kids:DiaryChild[]}){
  const queryClient=useQueryClient()
  const [tab,setTab]=useState<'entries'|'template'>('entries')
  const [childFilter,setChildFilter]=useState('all')
  const [monthFilter,setMonthFilter]=useState('')
  const [selectedEntry,setSelectedEntry]=useState<DiaryEntry|null>(null)
  const [answerDraft,setAnswerDraft]=useState<{entryId:string;values:Record<string,string>}>({entryId:'',values:{}})
  const [busy,setBusy]=useState(false)
  const [message,setMessage]=useState('')
  const [questionDraft,setQuestionDraft]=useState('')
  const [editingQuestion,setEditingQuestion]=useState('')
  const [confirmRemove,setConfirmRemove]=useState('')
  const today=dateInMexico()
  const promptsQuery=useQuery({queryKey:['diary-prompts',familyId],refetchInterval:role==='CHILD'?15000:false,queryFn:async()=>{const {data,error}=await supabase.from('diary_prompts').select('*').eq('family_id',familyId).order('position').order('created_at');if(error)throw error;return data as DiaryPrompt[]}})
  const entriesQuery=useQuery({queryKey:['diary-entries',familyId,role,profileId],queryFn:async()=>{let query=supabase.from('diary_entries').select('*').eq('family_id',familyId).order('entry_date',{ascending:false}).limit(500);if(role==='CHILD')query=query.eq('child_id',profileId);const {data,error}=await query;if(error)throw error;return data as unknown as DiaryEntry[]}})
  const childrenQuery=useQuery({queryKey:['diary-children',familyId],enabled:role==='PARENT',queryFn:async()=>{const {data,error}=await supabase.from('profiles').select('id,display_name,avatar').eq('family_id',familyId).eq('role','CHILD').order('created_at');if(error)throw error;return data as DiaryChild[]}})
  const prompts=promptsQuery.data??[]
  const entries=entriesQuery.data??[]
  const todayEntry=entries.find(entry=>entry.child_id===profileId&&entry.entry_date===today)
  const activeEntryId=todayEntry?.id??'new'
  const savedAnswers:Record<string,string>={}
  for(const answer of todayEntry?.answers??[])if(answer.prompt_id)savedAnswers[answer.prompt_id]=answer.answer
  const answers=answerDraft.entryId===activeEntryId?answerDraft.values:savedAnswers
  const setAnswer=(promptId:string,value:string)=>setAnswerDraft({entryId:activeEntryId,values:{...answers,[promptId]:value}})

  const refreshEntries=()=>queryClient.invalidateQueries({queryKey:['diary-entries',familyId]})
  const visibleEntries=entries.filter(entry=>(role==='CHILD'||childFilter==='all'||entry.child_id===childFilter)&&(!monthFilter||entry.entry_date.startsWith(monthFilter)))
  const childName=(id:string)=>kids.find(kid=>kid.id===id)?.display_name??childrenQuery.data?.find(kid=>kid.id===id)?.display_name??'Tu hijo'

  async function saveEntry(event:React.FormEvent){
    event.preventDefault()
    const currentAnswers=prompts.map(prompt=>({prompt_id:prompt.id,question:prompt.question,answer:(answers[prompt.id]??'').trim()})).filter(answer=>answer.answer)
    const currentIds=new Set(prompts.map(prompt=>prompt.id))
    const preserved=(todayEntry?.answers??[]).filter(answer=>answer.prompt_id&&!currentIds.has(answer.prompt_id))
    const snapshot=[...currentAnswers,...preserved]
    if(!snapshot.length){setMessage('Escribe al menos una respuesta para guardar tu diario.');return}
    setBusy(true);setMessage('')
    const {error}=await supabase.from('diary_entries').upsert({family_id:familyId,child_id:profileId,entry_date:today,answers:snapshot as never,updated_at:isoNow()},{onConflict:'child_id,entry_date'})
    setBusy(false)
    if(error){setMessage(error.message);return}
    setMessage('Tu día quedó guardado en el diario.')
    await refreshEntries()
  }

  async function saveQuestion(event:React.FormEvent){
    event.preventDefault()
    const question=questionDraft.trim()
    if(question.length<3)return
    setBusy(true);setMessage('')
    const result=editingQuestion
      ? await supabase.from('diary_prompts').update({question}).eq('id',editingQuestion).eq('family_id',familyId)
      : await supabase.from('diary_prompts').insert({family_id:familyId,question,position:(prompts.at(-1)?.position??0)+1})
    setBusy(false)
    if(result.error){setMessage(result.error.message);return}
    setQuestionDraft('');setEditingQuestion('');setMessage(editingQuestion?'Pregunta actualizada.':'Pregunta agregada.')
    await queryClient.invalidateQueries({queryKey:['diary-prompts',familyId]})
  }

  async function removeQuestion(prompt:DiaryPrompt){
    setBusy(true);setMessage('')
    const {error}=await supabase.from('diary_prompts').delete().eq('id',prompt.id).eq('family_id',familyId)
    setBusy(false)
    if(error){setMessage(error.message);return}
    setConfirmRemove('');setMessage('Pregunta quitada. Las entradas anteriores conservarán su texto.')
    await queryClient.invalidateQueries({queryKey:['diary-prompts',familyId]})
  }

  const intro=<div className="page-intro"><div><span className="eyebrow">{role==='CHILD'?'TUS RECUERDOS':'EN FAMILIA'}</span><h2>{role==='CHILD'?'Mi diario':'Diario familiar'}</h2><p>{role==='CHILD'?'Guarda algo de cada día. Puedes volver a leerlo cuando quieras.':'Acompaña sus días y personaliza las preguntas que les ayudan a contar cómo se sienten.'}</p></div></div>
  const parentTabs=role==='PARENT'&&<div className="filter-row diary-tabs"><button className={`filter-pill ${tab==='entries'?'active':''}`} onClick={()=>{setTab('entries');setMessage('')}}><BookOpen size={14}/> Entradas</button><button className={`filter-pill ${tab==='template'?'active':''}`} onClick={()=>{setTab('template');setMessage('')}}><Pencil size={14}/> Preguntas guía</button></div>

  return <>
    {intro}{parentTabs}{message&&<div className="notice dismissible" onClick={()=>setMessage('')}>{message}<button className="icon-button" aria-label="Cerrar aviso" onClick={event=>{event.stopPropagation();setMessage('')}}><X size={15}/></button></div>}
    {role==='PARENT'&&tab==='template'?<>
      <section className="panel diary-template-panel"><div className="diary-section-heading"><div><span className="eyebrow">PLANTILLA DIARIA</span><h3>Preguntas para inspirar</h3><p>Estas preguntas aparecerán cuando los niños escriban. Sus entradas anteriores conservarán las respuestas originales.</p></div><span className="diary-count">{prompts.length} / 12</span></div>
        <form className="diary-add-question" onSubmit={saveQuestion}><label className="sr-only" htmlFor="diary-question">Nueva pregunta</label><input id="diary-question" maxLength={180} value={questionDraft} onChange={event=>setQuestionDraft(event.target.value)} placeholder={editingQuestion?'Editar pregunta…':'Ej. ¿Qué te hizo sentir orgulloso hoy?'} required/><button className="button primary" disabled={busy||(!editingQuestion&&prompts.length>=12)}><>{editingQuestion?<Check size={15}/>:<Plus size={15}/>} {editingQuestion?'Guardar':'Agregar pregunta'}</></button>{editingQuestion&&<button type="button" className="button subtle" onClick={()=>{setEditingQuestion('');setQuestionDraft('')}}>Cancelar</button>}</form>
        <div className="diary-prompt-list">{prompts.map((prompt,index)=><article className="diary-prompt-row" key={prompt.id}><span className="diary-prompt-number">{index+1}</span><p>{prompt.question}</p>{confirmRemove===prompt.id?<div className="diary-row-actions"><button className="button small subtle" disabled={busy} onClick={()=>setConfirmRemove('')}>Conservar</button><button className="button small danger-button" disabled={busy} onClick={()=>void removeQuestion(prompt)}>Quitar</button></div>:<div className="diary-row-actions"><button className="icon-button" title="Editar pregunta" onClick={()=>{setEditingQuestion(prompt.id);setQuestionDraft(prompt.question)}}><Pencil size={15}/></button><button className="icon-button diary-delete" title="Quitar pregunta" disabled={prompts.length<=1||busy} onClick={()=>setConfirmRemove(prompt.id)}><Trash2 size={15}/></button></div>}</article>)}{!prompts.length&&<div className="empty-state">No hay preguntas en la plantilla.<p>Agrega una para que los niños tengan por dónde empezar.</p></div>}</div><p className="help-text diary-template-hint">Conviene dejar al menos una pregunta para que siempre tengan una idea para comenzar.</p>
      </section>
    </>:<>
      {role==='CHILD'&&<form className="panel diary-write-panel" onSubmit={saveEntry}><div className="diary-section-heading"><div><span className="eyebrow">{todayEntry?'TU ENTRADA DE HOY':'UN MOMENTO PARA TI'}</span><h3>{formatDate(today,{weekday:'long',day:'numeric',month:'long'})}</h3><p>{todayEntry?'Puedes volver a escribir o completar tus respuestas.':'No tiene que ser perfecto; escribe lo que quieras recordar.'}</p></div><div className="diary-calendar-icon"><CalendarDays size={20}/></div></div>
        <div className="diary-answer-fields">{prompts.map((prompt,index)=><label className="diary-answer-field" key={prompt.id}><span><i>{index+1}</i>{prompt.question}</span><textarea maxLength={2000} rows={2} value={answers[prompt.id]??''} onChange={event=>setAnswer(prompt.id,event.target.value)} placeholder="Escribe aquí…"/></label>)}{!prompts.length&&<div className="notice">Tu familia aún no ha agregado preguntas guía. Pídeles que agreguen una desde su cuenta.</div>}</div>
        <div className="diary-write-footer"><span>{todayEntry?'Tu entrada se puede editar durante el día.':'Solo tú y tu familia pueden leer tus entradas.'}</span><button className="button primary" disabled={busy||!prompts.length}><Save size={15}/>{busy?'Guardando…':todayEntry?'Guardar cambios':'Guardar mi día'}</button></div>
      </form>}
      <section className="diary-archive"><div className="diary-section-heading diary-archive-heading"><div><span className="eyebrow">{role==='CHILD'?'TUS DÍAS ANTERIORES':'BITÁCORA FAMILIAR'}</span><h3>{role==='CHILD'?'Archivo de recuerdos':'Entradas de los niños'}</h3><p>{role==='CHILD'?'Abre una fecha para volver a leer lo que escribiste.':'Elige un hijo o un mes para encontrar una entrada.'}</p></div><span className="diary-count">{visibleEntries.length}</span></div>
        <div className="diary-filters">{role==='PARENT'&&<label>Hijo<select value={childFilter} onChange={event=>setChildFilter(event.target.value)}><option value="all">Todos los hijos</option>{(childrenQuery.data??kids).map(kid=><option value={kid.id} key={kid.id}>{kid.display_name}</option>)}</select></label>}<label className="diary-month-filter"><CalendarDays size={15}/><span className="sr-only">Filtrar por mes</span><input type="month" value={monthFilter} onChange={event=>setMonthFilter(event.target.value)}/>{monthFilter&&<button type="button" className="icon-button" title="Mostrar todas las fechas" onClick={()=>setMonthFilter('')}><X size={14}/></button>}</label></div>
        {entriesQuery.isLoading?<div className="panel diary-empty">Cargando entradas…</div>:visibleEntries.length?<div className="diary-entry-grid">{visibleEntries.map(entry=><button type="button" className="diary-entry-card" key={entry.id} onClick={()=>setSelectedEntry(entry)}><span className="diary-entry-date"><CalendarDays size={15}/>{formatDate(entry.entry_date,{day:'numeric',month:'short',year:'numeric'})}</span>{role==='PARENT'&&<span className="diary-child-name">{childName(entry.child_id)}</span>}<strong>{entry.answers.length} {entry.answers.length===1?'respuesta':'respuestas'}</strong><p>{entry.answers.find(answer=>answer.answer)?.answer??'Entrada sin texto'}</p><span className="diary-entry-open">Leer entrada <ChevronRight size={14}/></span></button>)}</div>:<div className="panel diary-empty"><span className="diary-empty-icon"><BookOpen size={22}/></span><strong>{monthFilter?'No hay entradas en este mes':'Todavía no hay entradas'}</strong><p>{role==='CHILD'?'Tu primera entrada quedará guardada aquí.':'Cuando tus hijos escriban en su diario, sus entradas aparecerán aquí.'}</p></div>}
      </section>
    </>}

    {selectedEntry&&<div className="modal-backdrop" onMouseDown={event=>{if(event.target===event.currentTarget)setSelectedEntry(null)}}><section className="modal-card diary-entry-modal" role="dialog" aria-modal="true" aria-label={`Entrada del ${formatDate(selectedEntry.entry_date)}`}><div className="modal-head"><div><span className="eyebrow">{role==='PARENT'?childName(selectedEntry.child_id):'MI DIARIO'}</span><h2>{formatDate(selectedEntry.entry_date)}</h2></div><button className="icon-button" aria-label="Cerrar entrada" onClick={()=>setSelectedEntry(null)}><X size={18}/></button></div><div className="diary-reading-answers">{selectedEntry.answers.map((answer,index)=><article className="diary-reading-answer" key={`${selectedEntry.id}-${index}`}><h3>{answer.question}</h3><p>{answer.answer}</p></article>)}</div><div className="diary-modal-footer"><span>Una página de tu historia.</span><button className="button subtle" onClick={()=>setSelectedEntry(null)}>Cerrar</button></div></section></div>}
  </>
}
