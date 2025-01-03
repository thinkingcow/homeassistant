<!-- used with "fetch" to issue text commands -->
<if query.say>
  <if query.verbose>
    <set namespace=local name=v value="-v">
  </if>
  <exec prepend=what. command="/home/suhler/bin/speak ${v} -h ${mqtt_host} ${query.say}" timelimit=5000>
  <abort>
</if>

<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<!--
  styles:
    tab - one of the tabs
    section - one of the sections for a tab
    group - a tab or section
    Timers, Radio, ... matches a tab's value
    hide: display:none
    direct: a "button" command - fetch() the button.value
-->
<body>
<style eval=true>
 body {
   position: absolute; background: #FDD;
   line-height: ${query.spacing#130}%;
 }
 div {
   font-size: ${query.size#130}%;
 }
 button {
   text-align: bottom; font-size: ${query.button#110}%; 
   border-radius: ${query.radius#20}%;
   border: 2px outset #333;
   margin: ${query.margin#1px};
 }
 img {
   width: 5em;
   vertical-align: bottom;
   display: inline;
 }

 select {
   font-size: ${query.select#160}%;
 }
 .big {
   color: magenta; font-size: 150%;
 }
 .selected {
   color: green;
   font-weight: bold;
   border-color: green;
   border: 4px outset #333;
 }
 .error {
   color: red;
 }
 .hide {
   display: none;
 }
 #range {
  width: 70%;
 }
</style>

<div>
  <img onclick="do_send('what are the timers')" src="/grasshopper.svg" />
  <br/>
  <foreach name=i list="Timers,Radio,Kitchen,Weather" delim=",">
    <button id="${i}" value="${i}" class="${i} tab group"><get i></button>
  </foreach>
</div>
<hr>
<div class="Timers group section">
  <b>Set Timer minutes:</b><br/>
  <div id=t1><input type=range id=range min=1 max=59 oninput="do_change()"><button id=any class=direct name=say>??</button></div>
  <div>
    <button class=direct value="what are the timers">what?</button>
    <foreach name=i list="pizza,egg,bread,englishmuffin,crumpet,cookie,popover" delim=",">
      <button id="${i}_d" class=direct  value="set the ${i} timer"><get name=i> </button>
    </foreach>
  </div>
  <br/>
  <div id=t2>
    <foreach name=i list="1,3,5,10,15,20,30,45" delim=",">
      <button class=direct value="set the ${i} minute timer"><get name=i></button>
    </foreach>
  </div>
  <div>
    <br/>
    <b>Add minutes to Timer</b><br>
    <button class=direct value="add 30 seconds to that timer">1/2</button>
    <button class=direct value="add 1 minute to that timer">1</button>
    <foreach name=i list="2,3,5,10,15,30" delim=",">
      <button value="add ${i} minute to that timer" class="direct"><get name=i></button>
    </foreach>
    <br/>
    <button class=direct value="cancel that timer">Cancel timer</button>
  </div>
</div>

<div class="Radio group section" id=Radio>
  <button class=direct value="what am I listening to">status</button>
  <button class=direct value="pause Radio">pause</button>
  <button class=direct value="play Radio">play</button>
  <button class=direct value="increase the volume">louder</button>
  <button class=direct value="decrease the volume">softer</button>
  <button class=direct value="next track">next<br/>track</button>
  <button class=direct value="previous track">previous<br/>track</button>
  <br/>
  Playlist:
  <input id=list type=range>
  <span id=list_label>0</span><br/>
  <button class=direct type=submit id=playlist value="tune to all">Select</button>
</div>

<div class="Kitchen group section" id=Kitchen>
  <div>
    <b>Fume Hood:</b>
    <button class=direct value="turn on the fume hood">On</button>
    <button class=direct value="turn off the fume hood">Off</button>
  </div>
  <br/>
  <div>
  <b>Units Conversion to grams</b></br>
  <input id=quant type=range>
  <span id=quant_label>0</span><br/>
  <input id=frac type=range>
  <span id=frac_label>0</span><br/>
  <input id=units type=range>
  <span id="units_label">0</span><br/>
  <input id=food type=range>
  <span id="food_label">0</span>
  </div>
  <button id=convert value=convert>Convert</button>
</div>

<div class="Weather group section" id=Weather>
    <button class=direct value="what time is it">time now</button>
    Sun:<button class=direct value="sunrise">rise</button>/<
              button class=direct value="sunset">set</button>
  <p><b>Weather:</b></br>
    <button class=direct value="weather summary">summary</button>
    <button class=direct value="what is the weather today">today</button>
    <button class=direct value="what is the weather tomorrow">tomorrow</button>
  </p><p><b>Sprinklers:</b><br/>
    <button class=direct value="sprinkler status">summary</button>
    <button class=direct value="pause sprinklers">pause</button>
    <button class=direct value="cancel sprinkler pause">unpause</button>
  </p>
</div>
<p id="cmd" class=big>status</p>
</body>

<script>
  console.log("reload");
  function id(x) {
    return document.getElementById(x);
  }

  // run function for each element in this class
  function eachClass(cls, f) {
    Array.from(document.getElementsByClassName(cls)).forEach(el => f(el));
  }

  // Turn a select list into a range.
  function range_connect(name, list) {
    const v = list;
    let r = document.getElementById(name);
    let l = document.getElementById(name + "_label");
    r.min=0;
    r.value=0;
    l.innerHTML = v[0];
    r.max=v.length-1;
    r.oninput = function() {
      l.innerHTML = v[this.value];
    }
  }

  // Display status message
  function status(s, err) {
    id("cmd").innerHTML=s;
    let cl=id("cmd").classList;
    err ? cl.add("error") : cl.remove("error");
  }

  // set the timer to a specified minute value
  function do_change() {
    let v = id("range").value;
    id("any").firstChild.data=v;
    id("any").value="set the " + v + " minute timer";
  }

  // Sent the specified text to MQTT
  function do_click(q) {
    fetch("?say=" + encodeURIComponent(q));
    status(q);
  }

  // Send the text query to MQTT and display text (or error)
  function do_fetch(el) {
    console.log(fetch,el);
    do_send(el.target.value);
  }

  function do_send(say) {
    let f = new FormData();
    f.append("say", say);
    status("Sending Request...", true);
    fetch("", {body: f, method: "post"}).then(
      e=>{status(say)},
      e=>{status("Oops", true)});
  }

  // units conversion selection to text
  function do_convert(e) {
    let units=id("units_label").innerHTML;
    let frac=id("frac_label").innerHTML;
    let quant=id("quant_label").innerHTML;
    let food=id("food_label").innerHTML;
    let unit = units.slice(0, -1);
    let say="";
    if (quant == "0" && frac == "0") {
      status("Nothing to convert!", true);
      return;
    }
    if (quant == "0" && frac != "0") {
      say = `how much does ${frac} ${unit} of ${food} weigh`;
    } else if (frac == "0" && quant == "1") {
      say = `how much does a  ${unit} of ${food} weigh`;
    } else if (frac == "0") {
      say = `how much do ${quant} ${units} of ${food} weigh`;
    } else if (quant == "1") {
      say = `how much does one and ${frac} ${units} of ${food} weigh`;
    } else {
      say = `how much does ${quant} plus ${frac} ${unit} of ${food} weigh`;
    }
    do_send(say);
  }

  // Select the named tab and its contents
  function do_tab(el) {
      let t=el.value;
      status(t + " tab");
      eachClass("tab", el => el.classList.remove("selected"));
      eachClass(t, el => el.classList.add("selected"));
      eachClass("section",el => el.classList.add("hide"));
      eachClass(t, el => el.classList.remove("hide"));
  }

  function init() {
    console.log("init");
    eachClass("direct", el => el.onclick=do_fetch);
    eachClass("tab",el => el.addEventListener('click', function(evt) {
      do_tab(evt.target);
    }));
    id("convert").onclick=do_convert;
    id("list").onchange=function() {
      let v = "tune to " + id("list_label").innerHTML;
      id("playlist").value=v;
      id("playlist").textContent=v;
    };
    do_tab(id("Timers"));
    range_connect("units", ["cups","pints","quarts","sticks","tablespoons","teaspoons"]);
    range_connect("frac", ["0", "one eighth", "one quarter", "one third","one half","two thirds","three quarters"]);
    range_connect("quant", ["0", "1", "2", "3"]);
    range_connect("food",["baking powder","baking soda","brown sugar","butter","buttermilk","canola oil","chocolate chips","flour","honey","kosher salt","milk","olive oil","peanut butter","pecan pieces","raisins","rolled oats","salt","sour cream","sugar","table salt","water","white sugar","yoghurt"]);
    range_connect("list",["k q e d", "w g b h", "bach", "christmas", "clarinet", "classical", "flute", "jazz", "rock", "saxophone"]);
    do_change();
  }
  window.onload=init;
</script>
</body>
