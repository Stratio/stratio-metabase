
function autoLogin() {
  var xhttp = new XMLHttpRequest();
  xhttp.open("POST", "api/session", true);
  xhttp.setRequestHeader("Content-Type", "application/json");
  xhttp.send(JSON.stringify({username:"aa@gmail.com", password:"bbbbb"}));
  xhttp.onreadystatechange = function() {
    if (xhttp.readyState === 4) {
      if (xhttp.status === 200) {
        window.location.reload();
      }
    }
  };
}

function checkSession() {
  var req = new XMLHttpRequest();
  req.open("GET", "api/user/current", true);
  req.onreadystatechange = function() {
    if (req.readyState === 4) {
      if (req.status === 401) {
        console.log("Not currently authorized, trying to login via headers");
        autoLogin();
      }
    }
  };
  req.send();
}

checkSession();
