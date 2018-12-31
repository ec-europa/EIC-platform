(function () {

  
  var _OLD_REFS = []
  var _OLD_STYLE = {}

  // Opens up modal window editor 
  // Used for event meta-data editor
  // DEPRECATED: replace with AXEL-FORMS command
  function showItemDetails(ev) {
    var target = $(ev.target),
        src, key, wrapper, ed, 
        goal = 'update';
    // 1. find data source and key to identify target editor
    src = target.attr('data-event');
    key = 'events-management'

    if (src) {
      wrapper = $axel('#c-' + key);
      template = src + ".template";
      src = src + ".xml";
      ed = $axel.command.getEditor('c-' + key);

      ed.attr('data-template', ''); // trick to avoid buffering
      // no data-src since template is pre-filled with defaults
      ed.transform(template);
      if (wrapper.transformed()) {
        // set data source for 'save' command in modal
        ed.attr('data-src', src);
        $('#c-'+ key).bind('axel-cancel-edit', function() { $('#c-' + key + '-modal').modal('hide'); });
        $('#c-' + key + '-modal').modal('show');
      }
      $('#c-' + key + '').bind('axel-save-done', function() { $('#c-' + key + '-modal').modal('hide'); } );
    }
  }

  // Global network communication error handler (see also core/oppidum.js in AXEL-FORMS)
  // As per jQUery Ajax error callback data.status may be error, timeout, notmodified, parseerror
  // or per the application unexpected
  function networkErrorCb (event, data) {
    var msg;
    if (data.status === 'timeout') {
      msg = "The server is not answering. It is possible that your internet connexion is lost. The application will try to reload the page. Please check that your command hasn't been taken into account in spite of the absence of answer before submitting it again !";
      alert(msg);
      window.location.reload();
    } else {
      if (data.status === 'unexpected') {
        msg = "The server has returned an unexpected answer. Please check that your command hasn't been taken into account in spite of the unexpected answer before submitting it again !";
      } else {
        msg = $axel.oppidum.parseError(data.xhr, data.status, data.e);
      }
      alert(msg);
    }
  }
  
  function closeChoice2Popup (e) {
    // temporary hack the time 'choice2' handles this by itself
    var sel = $(e.target).closest('.axel-choice2'),
        target = sel.get(0);
    if (0 === sel.size()) {
      $('ul.choice2-popup1').removeClass('show');
    } else {
      $('.axel-choice2').filter( function (i,e) { return e !== target; }).children('ul.choice2-popup1').removeClass('show');
    }
  }

  // **************************
  // *** Rankinglist editor ***
  // **************************

  function indexLists( list, start ) {
    $( "#ranking-editor div#index-" + list ).find('li.ranking-ui').each(
      function() {
        var ul = $(this).parent(),
            freezer = ul.parent().parent().find('ul.freeze'),
            frozen = ul.hasClass('freeze') ? 0 : freezer.find('li.ranking-ui').size(),
            index = ul.find('li.ranking-ui').index($(this)) + frozen,
            link = $($(this).find('div').find('a').get(0)).text(),
            delim = $($(this).find('div').find('a').get(0)).find('br'),
            i = $($(this).find('div').find('a').get(0)).find('i');
        if (link.indexOf(':') !== -1) {
          linkafter = (index + start) + ': ' + link.substring(link.indexOf(':') + 2, link.length);
        } else {
          linkafter = (index + start) + ': ' + link;
        }
        if (delim.length > 0) {
          linkaft = linkafter.substring(0,15) + '<br/>' + linkafter.substring(15, linkafter.length);
        } else {
          linkaft = linkafter;
        }
        $($(this).find('div').find('a').get(0)).text('');
        $($(this).find('div').find('a').get(0)).prepend(linkaft);
        if (i !== null) {
          $($(this).find('div').find('a').get(0)).append(i);
        }
      });
  }

  function indexAll() {
    indexLists( 'main', 1 );
    indexLists( 'reserve', $( "#ranking-editor div#index-main" ).find('li.ranking-ui').length + 1 );
    indexLists( 'reject', $( "#ranking-editor div#index-main" ).find('li.ranking-ui').length + $( "#ranking-editor div#index-reserve" ).find('li.ranking-ui').length + 1 );
    indexLists( 'trash', $( "#ranking-editor div#index-main" ).find('li.ranking-ui').length + $( "#ranking-editor div#index-reserve" ).find('li.ranking-ui').length  + $( "#ranking-editor div#index-reject" ).find('li.ranking-ui').length + 1 );
  }

  function emphasize() {
    var refs = $axel('#search-editor').text().split(',');
    var last = refs[refs.length - 1];

    var style = "font-size:12px;background-color: rgb(11, 194, 0); background-image: linear-gradient(to bottom, rgb(31, 147, 0), rgb(31, 191, 0));";

    // make it appear again at the same time if hidden
    for (var i=0; i < refs.length; i++)
    {
      var li = $("#ranking-editor ul li.ranking-ui[data-id='" + refs[i] + "']");
      if ( _OLD_STYLE[ refs[i] ] == undefined ) {
        _OLD_STYLE[ refs[i] ] = li.find('a.btn.btn-primary').attr('style');
      }
      li.find('a.btn.btn-primary').attr('style', style);
      li.attr('style','margin-bottom:10px;max-width:200px');
    }

    var toggle = _OLD_REFS.filter( a => false === refs.some( b => a ===b ) );

    for (var i=0; i < toggle.length; i++) {

      var li = $("#ranking-editor ul li.ranking-ui[data-id='" + toggle[i] + "']");
      li.find('a.btn.btn-primary').attr('style', _OLD_STYLE[ toggle[i] ] );
      
      if ( $('#hide-unselected').prop('checked') ) {
        li.attr('style','display:none');
      }
    }

    _OLD_REFS = refs;

    if (refs[0] == '') { $axel("#search-editor").load('<Data/>'); hideUnselected( false, true ); }
  }

  function hideUnselected( checked, reset ) {
    if ((_OLD_REFS.length == '0' || _OLD_REFS[0] == '') && !reset )
      $('#hide-unselected').prop('checked', false);
    else {
      var li = $("#ranking-editor ul li.ranking-ui");
      for (var i=0; i < li.length; i++) {
        if (_OLD_REFS.indexOf( $(li[i]).attr('data-id') ) == -1) {
          if ( checked ) {
            $(li[i]).attr('style','display:none');
          } else {
            $(li[i]).attr('style','margin-bottom:10px;max-width:200px');
          }
        }
      }
      if (reset) $('#hide-unselected').prop('checked', false);
    }
  }

  function commentsSaveDone (ev, editor, source, xhr) {
    var f = $('Filled', xhr.responseXML).attr('Id');
    var id = $('Filled', xhr.responseXML).attr('Id') || $('Empty', xhr.responseXML).attr('Id');
    if (f !== null) {
      $($('body li[data-id="' + id + '"]').find('a').get(0)).append("<i class='fa fa-comments-o fa-fw'/>");
    }
  }

  function init() {
    if ($ && $.datepicker) {
      $.datepicker.regional[''].dateFormat = "dd/mm/yy"; // english UK
    }
    $('body').bind('click', closeChoice2Popup);
    $('body').bind('axel-network-error', networkErrorCb);
    $(document).bind('axel-editor-ready', 
      function (ev, host) { 
        $(host).find("span.sg-hint[rel='tooltip']")
          .tooltip({ html: false })
          .bind('hidden', function(ev) { ev.stopPropagation(); });  // stopPropagation prevents tooltip 'hidden' event to hide modal windows when in modals
      });
    $(document).bind('axel-editor-ready', 
      function (ev, host) { 
        $(host).find("span.sg-mandatory[rel='tooltip']")
          .tooltip({ html: false })
          .bind('hidden', function(ev) { ev.stopPropagation(); });  // stopPropagation prevents tooltip 'hidden' event to hide modal windows when in modals
      });
    if (typeof $axel !== 'undefined') {
      $axel.command.install(document); // deferred axel installation
      $axel.addLocale('en', {
        errLoadDocumentStatus : function (values) { 
          var msg = $axel.oppidum.parseError(values.xhr, undefined, undefined, values.url);
          if (values.xhr.status === 401) {
            msg = msg + "\n\n" + "This may be because your session has expired. In that case you need to reload the page and to identify again. If you are in the middle of an editing action, open a new window to identify yourself, this should allow you to save again in the first window. If this problem persists please check that your browser accepts cookies.";
          }
          return msg;
        }
      });
      $axel.setLocale('en');

    $( "body ul#sortable-main.well" ).sortable({
      connectWith: "body ul#sortable-reserve, ul#sortable-trash",
      update : function(event, ui) {
        indexAll()
      }
    });

    $( "body ul#sortable-reserve.well" ).sortable({
      connectWith: "body ul#sortable-main, ul#sortable-trash",
      update : function(event, ui) {
       indexAll()
      }
    });

    $( "body ul#sortable-trash.well" ).sortable({
      connectWith: "body ul#sortable-reserve, ul#sortable-main",
      update : function(event, ui) {
        indexAll()
      }
    });
    indexAll()
      
      // DEPRECATED: for event meta-data editor
      $('#events-management').click(showItemDetails)
      $('#ranking-editor').click(showItemDetails);
      // DEPRECATED. resets content when showing different messages details in modal
      $('#c-events-management-modal').on('hidden', function() { $(this).removeData();});

      $('#hide-unselected').prop('checked', false)
      $('#hide-unselected').click( function () { hideUnselected( $(this).prop('checked'), false ) } )
      $('#reset-selection').click( function () { $axel("#search-editor").load('<Data/>'); emphasize(); hideUnselected( false, true ) } )

      $('#search-editor').find('ul.select2-choices').parent().parent().find('select').bind('axel-update', emphasize )
      $('#c-events-management').bind('axel-save-done', commentsSaveDone )
    }
    
    // white list filtering to skip 'select2' nodes in some AXEL algoritms
    xtiger.cross.log('debug', 'configuring dom white list filtering function');
    $axel.defaults.domMAXIter = 25000;
    $axel.defaults.domWhiteListFunc = function(n) { return !n.className || n.className.indexOf('select2-') === -1; }
  }

  jQuery(function() { init(); });
}());
