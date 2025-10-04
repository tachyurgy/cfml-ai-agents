<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CFML AI Agents</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0b0b11;--bg2:#111119;--bg3:#1a1a25;--bg4:#22222f;
  --accent:#00d4aa;--accent2:#00b894;--accent-dim:rgba(0,212,170,.12);
  --text:#e0e0e8;--text2:#9999aa;--text3:#666677;
  --red:#ff5566;--yellow:#ffcc44;--blue:#44aaff;
  --border:#2a2a3a;--radius:10px;
  --mono:'SF Mono','Fira Code','Cascadia Code',monospace;
  --sans:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
}
body{font-family:var(--sans);background:var(--bg);color:var(--text);min-height:100vh;line-height:1.6}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}

.container{max-width:900px;margin:0 auto;padding:40px 24px 80px}

header{text-align:center;margin-bottom:48px}
header h1{font-size:2rem;font-weight:700;letter-spacing:-.02em;margin-bottom:8px}
header h1 span{color:var(--accent)}
header p{color:var(--text2);font-size:1rem;max-width:500px;margin:0 auto}
.badge{display:inline-block;background:var(--accent-dim);color:var(--accent);font-size:.75rem;font-weight:600;padding:3px 10px;border-radius:20px;margin-bottom:16px;letter-spacing:.04em;text-transform:uppercase}

.input-area{position:relative;margin-bottom:32px}
.input-area textarea{
  width:100%;min-height:80px;padding:16px 60px 16px 20px;
  background:var(--bg3);border:1px solid var(--border);border-radius:var(--radius);
  color:var(--text);font-size:.95rem;font-family:var(--sans);
  resize:vertical;outline:none;transition:border-color .2s;
}
.input-area textarea:focus{border-color:var(--accent)}
.input-area textarea::placeholder{color:var(--text3)}
.send-btn{
  position:absolute;right:12px;bottom:16px;
  width:40px;height:40px;border-radius:50%;border:none;
  background:var(--accent);color:var(--bg);cursor:pointer;
  display:flex;align-items:center;justify-content:center;
  transition:transform .15s,opacity .15s;
}
.send-btn:hover{transform:scale(1.1)}
.send-btn:disabled{opacity:.3;cursor:not-allowed;transform:none}
.send-btn svg{width:18px;height:18px}

.examples{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:40px}
.examples button{
  background:var(--bg3);border:1px solid var(--border);border-radius:20px;
  color:var(--text2);font-size:.8rem;padding:6px 14px;cursor:pointer;
  transition:background .2s,color .2s,border-color .2s;font-family:var(--sans);
}
.examples button:hover{background:var(--bg4);color:var(--text);border-color:var(--accent)}

#trace{display:none}
#trace.visible{display:block}

.trace-header{
  display:flex;align-items:center;gap:12px;margin-bottom:20px;
  padding-bottom:16px;border-bottom:1px solid var(--border);
}
.trace-task{font-size:1.05rem;color:var(--text);flex:1}
.trace-status{
  font-size:.75rem;font-weight:600;padding:4px 12px;border-radius:20px;
  text-transform:uppercase;letter-spacing:.05em;
}
.trace-status.running{background:rgba(68,170,255,.15);color:var(--blue)}
.trace-status.completed{background:rgba(0,212,170,.15);color:var(--accent)}
.trace-status.error{background:rgba(255,85,102,.15);color:var(--red)}

.step{
  position:relative;margin-left:20px;padding:0 0 28px 28px;
  border-left:2px solid var(--border);
}
.step:last-child{border-left-color:transparent;padding-bottom:0}
.step::before{
  content:'';position:absolute;left:-7px;top:4px;
  width:12px;height:12px;border-radius:50%;
  background:var(--bg);border:2px solid var(--border);
  transition:border-color .3s,background .3s;
}
.step.tool_use::before{border-color:var(--blue);background:var(--blue)}
.step.answer::before{border-color:var(--accent);background:var(--accent)}
.step.error::before{border-color:var(--red);background:var(--red)}
.step.thinking::before{border-color:var(--yellow);background:var(--yellow);animation:pulse 1.2s ease-in-out infinite}

@keyframes pulse{0%,100%{opacity:1}50%{opacity:.3}}

.step-label{
  font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;
  margin-bottom:6px;
}
.step-label.tool{color:var(--blue)}
.step-label.thought{color:var(--yellow)}
.step-label.final{color:var(--accent)}
.step-label.err{color:var(--red)}

.step-content{
  background:var(--bg2);border:1px solid var(--border);border-radius:var(--radius);
  overflow:hidden;
}
.step-body{padding:14px 16px;font-size:.88rem;line-height:1.7}
.step-body pre{
  font-family:var(--mono);font-size:.82rem;white-space:pre-wrap;word-break:break-word;
  color:var(--text2);margin-top:8px;background:var(--bg);padding:10px 12px;
  border-radius:6px;max-height:300px;overflow-y:auto;
}
.step-body .tool-name{color:var(--blue);font-weight:600;font-family:var(--mono);font-size:.85rem}
.step-body .tool-args{color:var(--text2);font-size:.82rem;margin-top:4px}

.step-toggle{
  display:flex;align-items:center;justify-content:space-between;
  padding:10px 16px;cursor:pointer;user-select:none;
}
.step-toggle:hover{background:var(--bg3)}
.step-toggle .label{font-size:.85rem;font-weight:600}
.step-toggle .chevron{
  width:16px;height:16px;color:var(--text3);transition:transform .2s;
}
.step-toggle .chevron.open{transform:rotate(180deg)}
.collapsible{display:none;border-top:1px solid var(--border)}
.collapsible.open{display:block}

.final-answer{
  background:linear-gradient(135deg,rgba(0,212,170,.08),rgba(0,184,148,.04));
  border:1px solid rgba(0,212,170,.25);border-radius:var(--radius);
  padding:20px 24px;margin-top:8px;
}
.final-answer p{font-size:.95rem;line-height:1.8;white-space:pre-wrap}

.loading{text-align:center;padding:40px 0}
.loading .spinner{
  width:32px;height:32px;border:3px solid var(--border);
  border-top-color:var(--accent);border-radius:50%;
  animation:spin .8s linear infinite;margin:0 auto 12px;
}
@keyframes spin{to{transform:rotate(360deg)}}
.loading p{color:var(--text2);font-size:.9rem}

.footer{text-align:center;margin-top:60px;color:var(--text3);font-size:.8rem}
.footer a{color:var(--text2)}
</style>
</head>
<body>

<div class="container">
  <header>
    <div class="badge">ReAct Pattern</div>
    <h1>CFML <span>AI Agents</span></h1>
    <p>An AI agent that reasons step-by-step and uses tools to find answers. Built entirely in ColdFusion.</p>
  </header>

  <div class="input-area">
    <textarea id="taskInput" placeholder="Ask anything. The agent will think, use tools, and find the answer..." rows="3"></textarea>
    <button class="send-btn" id="sendBtn" onclick="runAgent()">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
    </button>
  </div>

  <div class="examples">
    <button onclick="setTask('What is the current date and time, and what day of the week will it be 100 days from now?')">Date math</button>
    <button onclick="setTask('Calculate the compound interest on $10,000 at 5.5% annual rate for 7 years, compounded monthly.')">Compound interest</button>
    <button onclick="setTask('Search the web for the latest news about ColdFusion and CFML development in 2026.')">Web search</button>
    <button onclick="setTask('What are the top 3 most expensive products in the database, and which customers have ordered them?')">Database query</button>
    <button onclick="setTask('Fetch the JSON from https://api.github.com/zen and tell me what philosophy it returned.')">HTTP request</button>
    <button onclick="setTask('How many seconds are there between January 1, 2000 and December 31, 2025?')">Time diff</button>
  </div>

  <div id="trace">
    <div class="trace-header">
      <div class="trace-task" id="traceTask"></div>
      <div class="trace-status" id="traceStatus"></div>
    </div>
    <div id="traceSteps"></div>
    <div id="finalAnswer"></div>
  </div>

  <div id="loading" style="display:none" class="loading">
    <div class="spinner"></div>
    <p id="loadingText">Agent is thinking...</p>
  </div>

  <div class="footer">
    <p>Powered by <a href="https://github.com/tachyurgy/cfml-ai-agents">cfml-ai-agents</a> &middot; CFML + Claude/OpenAI &middot; MIT License</p>
  </div>
</div>

<script>
function setTask(text){
  document.getElementById('taskInput').value=text;
  document.getElementById('taskInput').focus();
}

function escapeHTML(s){
  var d=document.createElement('div');d.textContent=s;return d.innerHTML;
}

async function runAgent(){
  var input=document.getElementById('taskInput');
  var task=input.value.trim();
  if(!task)return;

  var sendBtn=document.getElementById('sendBtn');
  sendBtn.disabled=true;

  var traceEl=document.getElementById('trace');
  var stepsEl=document.getElementById('traceSteps');
  var finalEl=document.getElementById('finalAnswer');
  var loadingEl=document.getElementById('loading');
  var statusEl=document.getElementById('traceStatus');
  var taskEl=document.getElementById('traceTask');

  traceEl.className='visible';
  stepsEl.innerHTML='';
  finalEl.innerHTML='';
  taskEl.textContent=task;
  statusEl.textContent='Running';
  statusEl.className='trace-status running';
  loadingEl.style.display='block';

  var thinkingPhrases=['Agent is thinking...','Reasoning about the task...','Deciding which tools to use...','Processing information...','Almost there...'];
  var phraseIdx=0;
  var phraseTimer=setInterval(function(){
    phraseIdx=(phraseIdx+1)%thinkingPhrases.length;
    document.getElementById('loadingText').textContent=thinkingPhrases[phraseIdx];
  },3000);

  try{
    var resp=await fetch('/handlers/api.cfc?method=index&path=/agent/run',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({task:task,maxSteps:10})
    });

    var data=await resp.json();
    clearInterval(phraseTimer);
    loadingEl.style.display='none';

    if(data.error){
      statusEl.textContent='Error';
      statusEl.className='trace-status error';
      finalEl.innerHTML='<div class="final-answer"><p>'+escapeHTML(data.message)+'</p></div>';
      sendBtn.disabled=false;
      return;
    }

    var trace=data.trace||{};
    var steps=trace.steps||[];

    statusEl.textContent=trace.status||'completed';
    statusEl.className='trace-status '+(trace.status||'completed');

    // Render steps with animation delay
    steps.forEach(function(step,i){
      setTimeout(function(){renderStep(step,stepsEl)},i*300);
    });

    // Render final answer after steps
    setTimeout(function(){
      if(data.result){
        finalEl.innerHTML='<div class="final-answer"><p>'+escapeHTML(data.result)+'</p></div>';
      }
      sendBtn.disabled=false;
    },steps.length*300+100);

  }catch(err){
    clearInterval(phraseTimer);
    loadingEl.style.display='none';
    statusEl.textContent='Error';
    statusEl.className='trace-status error';
    finalEl.innerHTML='<div class="final-answer"><p>Request failed: '+escapeHTML(err.message)+'</p></div>';
    sendBtn.disabled=false;
  }
}

function renderStep(step,container){
  var div=document.createElement('div');
  div.className='step '+step.type;
  div.style.opacity='0';div.style.transform='translateY(10px)';

  if(step.type==='tool_use'){
    var tc=step.toolCall||step.TOOLCALL||{};
    var tr=step.toolResult||step.TOOLRESULT||{};
    // Handle CFML case-insensitive keys
    var toolName=tc.name||tc.NAME||'unknown';
    var toolArgs=tc.arguments||tc.ARGUMENTS||tc['arguments']||{};
    var toolResult=tr.result||tr.RESULT||JSON.stringify(tr);
    var stepNum=step.step||step.STEP||'?';
    var thought=step.thought||step.THOUGHT||'';

    var html='<div class="step-label tool">Step '+stepNum+' &mdash; Tool Call</div>';
    html+='<div class="step-content">';
    html+='<div class="step-toggle" onclick="toggleCollapse(this)">';
    html+='<span class="label"><span class="tool-name">'+escapeHTML(toolName)+'</span></span>';
    html+='<svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>';
    html+='</div>';
    html+='<div class="collapsible open">';
    if(thought){
      html+='<div class="step-body"><strong>Thought:</strong> '+escapeHTML(thought)+'</div>';
    }
    html+='<div class="step-body"><div class="tool-args">Arguments:</div><pre>'+escapeHTML(JSON.stringify(toolArgs,null,2))+'</pre></div>';
    html+='<div class="step-body"><div class="tool-args">Result:</div><pre>'+escapeHTML(typeof toolResult==='string'?toolResult:JSON.stringify(toolResult,null,2))+'</pre></div>';
    html+='</div></div>';
    div.innerHTML=html;

  }else if(step.type==='answer'){
    var response=step.response||step.RESPONSE||'';
    var stepNum=step.step||step.STEP||'?';
    div.innerHTML='<div class="step-label final">Step '+stepNum+' &mdash; Final Answer</div>';

  }else if(step.type==='error'){
    var response=step.response||step.RESPONSE||'';
    var stepNum=step.step||step.STEP||'?';
    div.innerHTML='<div class="step-label err">Step '+stepNum+' &mdash; Error</div><div class="step-content"><div class="step-body">'+escapeHTML(response)+'</div></div>';
  }

  container.appendChild(div);

  // Animate in
  requestAnimationFrame(function(){
    div.style.transition='opacity .4s ease, transform .4s ease';
    div.style.opacity='1';div.style.transform='translateY(0)';
  });
}

function toggleCollapse(el){
  var content=el.nextElementSibling;
  var chevron=el.querySelector('.chevron');
  if(content.classList.contains('open')){
    content.classList.remove('open');
    chevron.classList.remove('open');
  }else{
    content.classList.add('open');
    chevron.classList.add('open');
  }
}

// Submit on Ctrl/Cmd+Enter
document.getElementById('taskInput').addEventListener('keydown',function(e){
  if((e.metaKey||e.ctrlKey)&&e.key==='Enter'){e.preventDefault();runAgent();}
});
</script>

</body>
</html>
