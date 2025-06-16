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
    if (myIn.includes("call terminated, reload!!") ) {  // call terminated, reload web page!!
      location.reload()
      return;
      } 
    // https://www.youtube.com/watch?v=vkqZC_rEkVA append a row
    const tbodyEl = document.querySelector("tbody");
    var cells=myIn.split("</td><td >");
    //alert("Number now=".concat(cells[2])); // e.g "<font color='DarkRed'>0160 123456</font>"
    var table = document.getElementById("callsList");
    var row = table.rows.length -1; // last row
    while (row > 0) {
      //alert("Table=".concat(table.rows[row].cells[2].innerHTML));
      // cells[2] is returned by console in double quotes, typeof(cells[2]) is string
      // table.rows[row].cells[2].innerHTML is returned by console in single quotes, typeof(cells[2]) is string
      // without .toString they are not equal, if it looks equal!????
      if (cells[2].toString==table.rows[row].cells[2].innerHTML.toString) { // after an ring we may have now an connect
        table.deleteRow(row); // delete the entry without extension
        break;
        }
      if (table.rows[row].cells[2].innerHTML==table.rows[row].cells[2].innerText) {
        break; // Entry without font tag for active call
        }
        row=row-1;
      }
    tbodyEl.innerHTML += myIn; // insert active call to table
    setBoxHeight();
    var o1=document.getElementById('mybox'); 
    var sy=o1.scrollHeight; 
    if (!!sy) {
      o1.scrollTo(0, sy);
      }
    }
   };
