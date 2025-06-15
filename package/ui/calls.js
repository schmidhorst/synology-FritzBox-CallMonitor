function setBoxHeight() { 
  var h0=window.innerHeight; 
  var o1=document.getElementById('mybox'); 
  var h1=o1.style.height; 
  var t1=o1.getBoundingClientRect().top; 
  h2=h0 - t1- 55; o1.style.height = h2+'px';
  };

// https://talent500.com/blog/server-sent-events-real-time-updates/
// https://developer.mozilla.org/de/docs/Web/API/EventSource : Statt 'new EventSource('/events');' 'new EventSource("sse.php");'

const eventSource = new EventSource('calls.cgi?action=event');

function myLoad() {
  setBoxHeight(); 
  var o1=document.getElementById('mybox'); 
  var sy=o1.scrollHeight; 
  if (!!sy) {
    o1.scrollTo(0, sy);
    }
  else {
    alert('ScrollY null');
    };
  console.log('eventSource.readyState=', eventSource.readyState, '(0=Connecting, 1=open, 2=closed)');
  };

window.onbeforeunload = (e) => {
  console.log('close before unload!');
  eventSource.close();
  };

eventSource.onerror = (e) => {
  console.log('eventSource Error occured');
  };

eventSource.onopen = (e) => {
  console.log('eventSource connection has been established');
  };

eventSource.onmessage = (e) => {
  e.preventDefault();
  // alert ("raw e.data=".concat(e.data));
  const myIn = e.data.replace(/data:/g,'').trim();
  if (myIn.length > 0) {
    if (myIn.includes("call terminated, reload!!") ) {  // call terminated, reload!!
      location.reload()
      return;
      } 
    // https://www.youtube.com/watch?v=vkqZC_rEkVA
    const tbodyEl = document.querySelector("tbody");
    tbodyEl.innerHTML += myIn;
    var o1=document.getElementById('mybox'); 
    var sy=o1.scrollHeight; 
    if (!!sy) {
      o1.scrollTo(0, sy);
      }
    }
   };
