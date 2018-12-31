(function () {
  // Opens a window with an iframe to display the current template source code
  // It uses the view-source: URL protocol with relative URLs, so currently it works
  // only with Firefox (chrome does not seem to like relative URLs)
  function viewTemplateSource (url) {
    var location, win, div, count = 0;
    location = "view-source:" + url;
    win = window.open(null, "Template source", 'width=800,height=800,location=no,toolbar=no,menubar=no');
    win.focus();
    // creates a document in popup window and default message for unsupported browsers
    win.document.open();
    win.document.write('To actually see the template source code in this window you must use a browser supporting the view-source protocol');
    win.document.close();
    win.document.title = "Source of '" + url + "'";
    div = win.document.createElement('div');
    div.innerHTML = '<iframe src="' + "javaScript:'To actually see the template source code in this window you must use a browser supporting the view-source protocol with relative URLs like Firefox'" + '" frameborder="0" style="width:100%;height:100%"><iframe>';
    win.document.body.replaceChild( div, win.document.body.firstChild );
    win.document.body.style.margin = "0";
    win.onload = function() {
      var doc = win.frames[0].document;
      $('pre', doc).css('white-space', 'pre-wrap'); // trick to wrap lines (Firefox)
    };
    // actually instructs to view template source
    // bind to load event to force a reload to avoid caching issue !
    $('iframe', div).bind('load', function () { if (!count++) { this.contentWindow.location.reload(true);} }).attr('src',location);
  }

  function init() {
    $axel.setup({ bundlesPath : 'static/cctracker/lib/axel/bundles', tabGroupNavigation: true });
    $('#x-model').bind('click', function() { viewTemplateSource($('#x-formular').val() + '?goal=model'); });
    $('#x-generate').bind('click', function() { viewTemplateSource($('#x-formular').val() + '?goal=save'); });
    $('#x-src').bind('click', function() { viewTemplateSource($('#x-formular').val() + '.xml'); });
    $('#x-test').bind('click', function() { 
      var target = $('#x-simulator').get(0);
      $axel('#x-simulator').transform($('#x-formular').val() + '?goal=test'); 
      $('#c-editor-errors').removeClass('af-validation-failed'); 
      $axel.command.install(document, target);
      $axel.binding.install(document, target);
      });
    $('#x-control').bind('click', function() { $axel('#x-simulator').transform($('#x-formular').val() + '?goal=save'); });
    $('#x-dump').bind('click', function() { alert($axel('#x-simulator').xml()); });
    $('#x-display').bind('click', function() { 
      var target = $('#x-simulator').get(0),
          curval = $('#x-formular').val(),
          tplurl = ($('#x-formular option[value="' + curval +'"]').attr('data-display') || curval.replace('forms/', 'templates/')) + '?goal=' + $('#x-mode').val();
      $('#x-simulator').html('<p>Loading <a target="_blank" href="' + tplurl + '">' + tplurl + '</a>...</p>');
      // $('body xt\\:use', t).attr('types','t_simulation')
      $axel('#x-simulator').transform(tplurl); 
      $('#c-editor-errors').removeClass('af-validation-failed'); 
      $axel.command.install(document, target);
      $axel.binding.install(document, target); 
      });
    $('#x-validate').bind('click', function() { $axel.binding.validate($axel('#x-simulator'), 'c-editor-errors', document, 'label') });
    $('#x-install').bind('click', function() { $('#x-simulator').load('forms/install?gen=' + $('#x-formular').val().replace('forms/','')); });
    $('#x-install-all').bind('click', function() { $('#x-simulator').load('forms/install?gen=' + encodeURIComponent($('#x-formular option').map(function(i,e) { return $(e).val().replace('forms/','') }).toArray().join('+'))); });
  }
  
  jQuery(function() { init(); });
}());
