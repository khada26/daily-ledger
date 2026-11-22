/* Daily Ledger offline worker. Bump VERSION when you publish a new index.html. */
var VERSION='ledger-v11',SHELL=['./','./index.html','./manifest.webmanifest','./icons/icon-192.png','./icons/icon-512.png','./icons/maskable-512.png','./icons/apple-touch-icon.png','./privacy.html'];
self.addEventListener('install',function(e){e.waitUntil(caches.open(VERSION).then(function(c){return c.addAll(SHELL);}).then(function(){return self.skipWaiting();}));});
self.addEventListener('activate',function(e){e.waitUntil(caches.keys().then(function(ks){return Promise.all(ks.filter(function(k){return k!==VERSION&&k.indexOf('ledger-')===0;}).map(function(k){return caches.delete(k);}));}).then(function(){return self.clients.claim();}));});
self.addEventListener('fetch',function(e){
  var r=e.request;if(r.method!=='GET')return;
  var u=new URL(r.url);
  if(u.origin===location.origin){
    // pages: try the network first so updates arrive, fall back to the saved copy offline
    if(r.mode==='navigate'||u.pathname.slice(-10)==='index.html'){
      e.respondWith(fetch(r).then(function(res){var cp=res.clone();caches.open(VERSION).then(function(c){c.put('./index.html',cp);});return res;}).catch(function(){return caches.match('./index.html');}));
      return;
    }
    e.respondWith(caches.match(r).then(function(m){return m||fetch(r).then(function(res){var cp=res.clone();caches.open(VERSION).then(function(c){c.put(r,cp);});return res;});}));
    return;
  }
  // fonts and other outside files: use the saved copy when offline
  if(/fonts\.(googleapis|gstatic)\.com$/.test(u.hostname)){
    e.respondWith(caches.open(VERSION).then(function(c){return c.match(r).then(function(m){var f=fetch(r).then(function(res){c.put(r,res.clone());return res;}).catch(function(){return m;});return m||f;});}));
  }
});
