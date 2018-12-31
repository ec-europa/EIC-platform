// starting from this point code can be copied to import coach search service
// .....................................................................
// .........................BEGIN CUT POINT.............................
// .....................................................................

/*****************************************************************************\
|                                                                             |
|  Client-side implementation of plain vanilla search by criteria             |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Requires :                                                                 |
|  - a search mask (see init() at the end for its #id)                        |
|  - $axel.command.makeTableCommand.makeTableCommand available in widgets.js  |
|  - a result table with a data-command="criteria-table"                      |
|    identified as #cm-criteria-table-results                                 |
|                                                                             |
|  Duplicates :                                                               |
|  - part of this code is duplicated in cm-suggest.js but this should be      |
|    no longer the case after we treat issue-209                              |
|                                                                             |
\*****************************************************************************/
(function () {

  DB = {};

  /////////////////////////
  // Table columns model //
  /////////////////////////

  var GENCRITERIA = {
    Name : {
      yes : '*',
      modal : 'cm-coach-summary',
      resource : 'suggest/summary/$_',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Country : {
      ascending : function(a, b) { return d3.ascending(a.Country, b.Country); },
      descending :  function(a, b) { return d3.descending(a.Country, b.Country); }
    },
    Perf : {
      ascending : function(a, b) { var i = a.Perf || 'ZZZ', j = b.Perf || 'ZZZ'; return d3.ascending(i, j); },
      descending :  function(a, b) { var i = a.Perf === undefined ? 'AAA' : a.Perf, j = b.Perf === undefined ? 'AAA' : b.Perf; return d3.descending(i, j); }
    },
    Summ : {
      yes : '*' 
    },
    Action : {
      button : '<button class="btn btn-small">Inspect</button>',
      callback : doInspectCoach
    },
  };
  
  ///////////////
  // Utilities //
  ///////////////

  // Converts code value to label using JSON Variables
  function decodeLabel ( convert, value ) {
    var trans, pos, output, res = "";
    if (convert) {
      trans = $.isArray(convert.Values) ? convert.Values : [ convert.Values ] || convert,
      pos = trans.indexOf(value),
      output = $.isArray(convert.Labels) ? convert.Labels : [ convert.Labels ] || convert;
      res = output[pos] || value;
    }
    return res;
  }

  // Converts code value to label using JSON Variables
  function decodeLabels ( convert, value ) {
    var input = value.split(","), output = [], k;
    while (k = $.trim(input.shift())) {
      output.push(decodeLabel(convert, k));
    }
    return output.join(", ");
  }

  // Forwards network error to main application controller
  function reportAjaxError ( xhr, status, e )  {
    $('body').trigger('axel-network-error', { xhr : xhr, status : status, e : e });
  }

  function enableUI() {
    var i;
    for(i = 0; i < arguments.length; i++) {
      $('#' + arguments[i]).removeAttr('disabled');
    }
  }

  function disableUI() {
    var i;
    for(i = 0; i < arguments.length; i++) {
      $('#' + arguments[i]).attr('disabled','disabled');
    }
  }

  function genPayloadFor( table ) {
    return '<SearchByCriteria>' + $axel("#cm-criteria-edit").xml() + '</SearchByCriteria>';
  }

  // heuristics to pretty print person name
  function prettyPrintName( n ) {
    var res = '', fn, ln;
    if (n) {
      if (n.LastName) {
        res = n.LastName.toUpperCase() + ' ';
      }
      ln = n.FirstName;
      if (ln) {
        ln = $.trim(ln);
        if (!/[a-z]/.test(ln)) { // all capital
          res += ln.charAt(0).toUpperCase() + ln.substr(1).toLowerCase();
        } else { // already ready
          res += ln.charAt(0).toUpperCase() + ln.substr(1);
        }
      }
    } else {
      res = "Profile w/o name";
    }
    return res;
  }

  ///////////////////////////////////////
  // Search by criteria row generation //
  ///////////////////////////////////////

  function decodePerf(d) {
    var res;
    if (d.Perf === -3) {
      res = '';
    } else if (d.Perf === -2) {
      res = 'n/a';
    } else if (d.Perf === -1) {
      res = 'n/c';
    } else {
      res = d.Perf;
    }
    if (d.Complete !== undefined) {
      if (d.Total !== undefined && d.Total !== d.Complete) {
        res = res + ' (' + d.Complete + ' of ' + d.Total + ')';
      } else {
        res = res + ' (' + d.Complete + ')';
      }
    } 
    return res;
  }

  // KWIC Javascript fallback when current algorithm didn't use fulltext index
  // Returns an array
  function kwicify(text) {
    var res = [], k, sep, tokens, matches;
    if (DB.KWIC && DB.KWIC.length > 0) {
      k = DB.KWIC.replace(/\*/g, ''),
      sep = new RegExp(k, 'ig'),
      tokens = text.split(sep),
      matches = text.match(sep);
      for (i = 0; i < tokens.length; i++) {
        res.push(tokens[i]);
        if (i < (tokens.length - 1)) {
          res.push({ match: '1', '#text' : matches[i] });
        }
      }
    } else {
      res.push(text);
    }
    return res;
  }

  // Turns Coach hash entry into Criteria table row
  function encodeCriteriaRow( d, encodeCell ) {
    // 1. formats model data :
    // - encodes numbers (could be done server side with json:literal) for column sorting
    // - competence and Context type promotion
    if (d.Competence) {
      d.Competence = parseFloat(d.Competence);
    }
    if (d.Context) {
      d.Context = parseFloat(d.Context);
    }
    if (d.Country) {
      d.Country = decodeLabel(DB.Variables['Countries'], d.Country);
    }
    if (d.Languages) {
      d.Languages = decodeLabels(DB.Variables['EU-Languages'], d.Languages);
    }
    if (d.Perf) {
      tmp = d.Perf.split(',');
      d.Perf = tmp[0];
      d.Complete = tmp[1];
      d.Total= tmp[2];
      if (d.Perf === '-') { // num key for sorting
        d.Perf = -3;
      } else if (d.Perf === 'n/a') {
        d.Perf = -2;
      } else if (d.Perf === 'n/c') {
        d.Perf = -1;
      } else {
        d.Perf = parseFloat(d.Perf);
      }
    }
    d.Name = prettyPrintName(d.Name);

    var text = '';
    
    if (d.Summ) {
      var kwic = typeof d.Summ.txt == "string" ? kwicify(d.Summ.txt) : d.Summ.txt;
      for (var i = 0; i < kwic.length; ++i) {
          if (kwic[i]['#text']) {
            text += '<span style="font-weight:bold">' +  xtiger.util.encodeEntities(kwic[i]['#text']) + '</span>'; 
          } else {
            text += xtiger.util.encodeEntities(kwic[i]);
          }
      }
/*
      var kwic = d.Summ.p
      if (kwic.constructor === Array) { 
        for (var i = 0; i < kwic.length; ++i)
          text += '<p>' + kwic[i].span[0]['#text'] + '<span style="font-weight:bold">'+ kwic[i].span[1]['#text'] + '</span>' + kwic[i].span[2]['#text'] + '</p>'
      }
      else
        text += '<p>' + kwic.span[0]['#text'] + '<span style="font-weight:bold">'+ kwic.span[1]['#text'] + '</span>' + kwic.span[2]['#text'] + '</p>'*/
    } 
    // 2. generates array for cell display
    var res = [
      encodeCell('Name', d),
      d.Languages,
      d.Country,
      decodePerf(d),
      text,
      encodeCell('Action')
    ];
    return res;
  }

  // Result table generation from Ajax JSON protocol response
  function submitSearchSuccess ( data, status, xhr ) {
    var tabname = data.Table,
        tabid = 'cm-' + tabname + '-results';
    DB.Variables = data.Variables;
    DB.KWIC = data.Keywords; // saved for Javascript KWIC fallback
    if (data.Coaches === undefined) {
      DB[tabname] = [];
    } else {
      DB[tabname] = $.isArray(data.Coaches) ? data.Coaches : [ data.Coaches ];
    }
    if (DB[tabname]) { // something to show
      $('#no-sample').hide();
      try {
        $axel.command.getCommand(tabname + '-table', tabid).execute(DB[tabname]).sort('Name');
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
      }
      $('#cm-' + tabname + '-competence-number').text(DB[tabname].length);
    } else { // nothing to show
      $('#no-sample').show();
      d3.selectAll('#cm-' + data.Table + '-results').style('display', 'none');
    }
    // Updates UI state (DEPRECATED ?)
    if (tabname === 'criteria') {
      enableUI('cm-criteria-mid-button', 'cm-criteria-high-button');
    }
    $('#cm-' + tabname + '-busy').hide();
  }

  /*****************************************************************************\
  |                                                                             |
  |  'back-to-search' command object                                            |
  |                                                                             |
  |*****************************************************************************|
  |                                                                             |
  |  Required attributes :                                                      |
  |  - data-overaly : name of the overlay view to close                         |
  |                                                                             |
  \*****************************************************************************/
  (function () {
  
    function BackToSearch ( identifier, node ) {
      var spec = $(node);
      var _overlay = spec.attr('data-overlay');
      spec.bind('click', function () { uninstallOverlay(_overlay); } );
    }

    $axel.command.register('back-to-search', BackToSearch, { check : false });
  }());

  // .....................................................................
  // ..........................END CUT POINT..............................
  // .....................................................................
  // starting from this points code diverges from Coach Match cm-search.js

  /////////////////////////
  // Overlays management //
  /////////////////////////

  // Hides fixed menus to reveal the overlay div
  function installOverlay (name) {
    $('#cm-tabs').add('#cm-header').hide();
    $('#cm-' +name + '-view').show();
    $('body').attr('id', ''); // remove padding-top
  };

  // Restore fixed menus and hide the overlay div
  function uninstallOverlay (name) {
    $('body').attr('id','c-skip-header');
    $('#cm-tabs').add('#cm-header').show();
    $('#cm-' +name + '-view').hide();
  };

  ///////////////
  // Inspector //
  ///////////////

  function submitInspectError ( xhr, status, e ) {
    $('#cm-inspect-busy').hide();
    $('#cm-inspect-content').html('Error while loading');
    $('#cm-inspect-shortlist-button').attr('data-coach', '');
    reportAjaxError(xhr, status, e);
  }

  // TODO: cache data-inspect onto table
  function submitInspectSuccess ( data, status, xhr ) {
    var cv;
    $('#cm-inspect-busy').hide();
    $('#cm-inspect-content').html(data);
    cv = $('#cm-inspect-content > div[data-cv-link]').attr('data-cv-link');
    if (cv) {
      $('#cm-inspect-cv-button').attr('href', cv).show();
    } else {
      $('#cm-inspect-cv-button').hide();
    }
    cv = $('#cm-inspect-content > div[data-cv-file]').attr('data-cv-file');
    if (cv) {
      $('#cm-inspect-pdf-button').attr('href', cv).show();
    } else {
      $('#cm-inspect-pdf-button').hide();
    }
    $('html, body').animate( { scrollTop : 0 }, 1000 );
  }

  // TODO: cache latest
  function doInspectCoach (id, key, target) {
    var table = target.closest('table');
    if (table.attr('data-inspect') !== id) {
      $('#cm-inspect-busy').show();
      installOverlay('inspect');
      $.ajax({
        url : 'suggest/inspect/' + id,
        type : 'post',
        async : false,
        data : '<Inspect/>',
        dataType : 'html',
        cache : false,
        timeout : 50000,
        contentType : "application/xml; charset=UTF-8",
        success : submitInspectSuccess,
        error : submitInspectError
      });
    } else {
      installOverlay('inspect');
    }
  }

  ////////////////////
  // Initialization //
  ////////////////////

  // Loads and generates search by criteria formular (only once)
  function initCriteriaSearch (event) {
    var ed = $axel.command.getEditor('cm-criteria-edit');
    if (ed) {
      ed.transform();
      // synchronous loading at the moment
      if ($axel('#cm-criteria-edit').transformed()) {
        enableUI('cm-criteria-mid-button', 'cm-criteria-high-button'); // DEPRECATED
      } else {
        $('#cm-criteria-tab-tab').one('click', initCriteriaSearch);
      }
    }
  }

  // TODO: extend 'axel-save-done' to avoid parsing JSON twice
  function ajaxSearchSuccess ( ev, editor, command, xhr ) {
    var jsonres = JSON.parse(xhr.responseText);
    submitSearchSuccess (jsonres.payload.MatchResults);
    $('#cm-fit-busy').hide(); // use event.data
    $('#cm-criteria-busy').hide();
  }

  function init() {
    // deferred tabs
    $('#cm-criteria-tab-tab').one('click', initCriteriaSearch);
    // commands
    $('#cm-criteria-edit').bind('axel-save', function () { $('#cm-criteria-busy').show(); });
    $('#cm-criteria-edit').bind('axel-save-done', ajaxSearchSuccess);
    $('#cm-criteria-edit').bind('axel-save-error', function () { $('#cm-criteria-busy').hide(); });
  }

  jQuery(function() { init(); });

  // records new commands before page ready handler
  $axel.command.makeTableCommand('criteria', encodeCriteriaRow, GENCRITERIA);
}());
