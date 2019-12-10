
function setCookie(name, value, expires, path, secure) {
  var today = new Date();
  today.setTime(today.getTime());
  if (expires) {
    expires = expires * 1000 * 60 * 60 * 24;
  }
  var expires_date = new Date(today.getTime() + (expires));
  document.cookie = name + '=' + escape(value) +
    ((expires) ? ';expires=' + expires_date.toGMTString() : '') + //expires.toGMTString()
    ((path) ? ';path=' + path : '') +
    ((secure) ? ';secure' : '');
}

function request(url, cFunction) {
  var xhttp;
  xhttp=new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      return cFunction(this);
    }
  };
  xhttp.open("POST", url, true);
  xhttp.setRequestHeader("Content-Type", "application/json");
  xhttp.send(JSON.stringify({username:"aa@gmail.com", password:"bbbbb"}));
}

function setCookieMetabase(sessionId) {
  var METABASE_SESSION_COOKIE = 'metabase.SESSION_ID';
  try {
    if (sessionId) {
      // set a session cookie
      setCookie(METABASE_SESSION_COOKIE, sessionId, "/", true);
    }
  } catch (e) {
    console.error("setSessionCookie:", e);
  }
}

function myFunction(xhttp) {
  var myArr = JSON.parse(xhttp.responseText);
  if (myArr.id) {
    setCookieMetabase(myArr.id);
    document.location = document.location;
    return true;
  } else {
    return false;
  }
}

function getCookie(name) {
  name = name + "=";
  var cookies = document.cookie.split(';');
  for(var i = 0; i <cookies.length; i++) {
    var cookie = cookies[i];
    while (cookie.charAt(0)==' ') {
      cookie = cookie.substring(1);
    }
    if (cookie.indexOf(name) == 0) {
      return cookie.substring(name.length,cookie.length);
    }
  }
  return "";
}

var session = getCookie('metabase.SESSION_ID');
if (session.length==0){
  request('api/session', myFunction);

}
