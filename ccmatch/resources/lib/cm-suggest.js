(function () {

  var DB = {};
  var DB_CUR;
  var COACH; // TODO: cache ?
  var SHORTLIST = [];
  var CUR_SME;
  var CUR_CRITERIA;
  var UUID;

  window.SL = SHORTLIST; // Temporary
  window.DB = DB; // Temporary

  /////////////////////////
  // Table columns model //
  /////////////////////////
  
  // utility sort function
  function orderAscend (a, b) {
    var i = a || 'ZZZ', 
        j = b || 'ZZZ'; 
    return d3.ascending(i, j);
  }

  // utility sort function
  function orderDescend (a, b) {
    var i = a === undefined ? 'AAA' : a, 
        j = b === undefined ? 'AAA' : b; 
    return d3.descending(i, j);
  }

  var GENCRITERIA = { // DEPRECATED
    Name : {
      yes : '*',
      modal : 'cm-coach-summary',
      resource : 'suggest/summary/$_',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Country : true, 
    Perf : {
      ascending : function(a, b) { return orderAscend(a.Perf, b.Perf); },
      descending :  function(a, b) { return orderDescend(a.Perf, b.Perf); }
    },
    Action : {
      button : '<button class="btn btn-small">Inspect</button>',
      callback : doInspectCoach
    },
  };

  var GENFIT = {
    Name : {
      yes : '*',
      modal : 'cm-coach-summary',
      resource : 'suggest/summary/$_',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Languages : true,
    Country : true,
    Competence : true,
    Context : true,
    Perf : {
      ascending : function(a, b) { return orderAscend(a.Perf, b.Perf); },
      descending :  function(a, b) { return orderDescend(a.Perf, b.Perf); }
    },
    Action : {
      button : '<button class="btn btn-small">Evaluate</button>',
      callback : doEvaluateCoach
    }
  };

  var GENSHORTLIST = {
    Name : {
      yes : '*',
      modal : 'cm-coach-summary',
      resource : 'suggest/summary/$_',
      ascending : function(a, b) { return d3.ascending(a.Name, b.Name); },
      descending :  function(a, b) { return d3.descending(a.Name, b.Name); }
    },
    Country : {},
    Perf : {
      ascending : function(a, b) { return orderAscend(a.Perf, b.Perf); },
      descending :  function(a, b) { return orderDescend(a.Perf, b.Perf); }
    },
    Action : {
      button : '<button class="btn btn-small" data-action="evaluate">Evaluate</button><button class="btn btn-small" data-action="remove">Remove</button>',
      callback : {
        'evaluate' : doEvaluateCoach,
        'remove' : doRemoveCoach
      }
    }
  };

  ///////////////
  // Utilities //
  ///////////////

  // TOC (could be XSLT generated)
  function makeTOC () {
    var toc, init, set, last;
    toc = $('#toc');
    init = toc.children('b').size() === 0;
    set = $('#cm-evaluation-view h3, #cm-evaluation-view h2');
    last = set.size() - 1;
    set.each(
      function(i, e) {
        if (i >= 4) {
          var t = $(e);
          if (init) {
            if (t.is('h2')) {
              toc.append((i === 4 ? '' : '<br/>') + '<b>' + t.text() + '</b> : ');
            } else {
              toc.append('<a class="toc" data-index="' + i + '">' + t.text() + '</a>' + (i !== last && set.get(i + 1).tagName.toUpperCase() === 'H3' ? ' | ' : ''));
            }
          }
          if (!t.is('h2') && (t.children('sup').size() === 0)) {
            t.append('<sup><a href="#toc" class="top" name="ancre_' + i + '">&#x25B2;</a></sup>');
          }
        }
      }
    );
    if (init) { // first time
      $('#cm-evaluation-view a.toc').click( function(ev) { //  vertical shift static header
         var l = $(ev.target).attr('data-index');
         var sel = 'a[name="ancre_' + l + '"]';
         var target = $(sel);
         $('html, body').animate( { scrollTop : target.offset().top - 100 }, 800 );
         ev.preventDefault();
         }
      );
    }
    $('a.top').click( function(ev) { //  skip Oppidum developer tools static header
        $('html, body').animate( { scrollTop : 0 }, 800 );
        ev.preventDefault();
      }
    );
  }

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
  
  // Generates Payload to invoke Coach Match services
  function genPayloadFor( table ) {
    var envelope = $("#cm-service-envelope").text(),
        payload, res;
    if (table === 'cm-criteria-results') { // DEPRECATED: search by criteria
      payload = $axel("#cm-criteria-edit").xml();
    } else if (table === 'cm-refine-criteria-results') { // refine by criteria
      payload = $("#cm-search-by-fit").text() + $axel("#cm-criteria-edit").xml();
    } else if (table === 'cm-handout') { // show handout for printing  
      payload = '<Handout>' + $("#cm-search-by-fit").text() + genShortList(table) + '</Handout>';
    } else { // assumes 'cm-fit-results' search by fit
      payload = $("#cm-search-by-fit").text();
    }
    res = envelope.replace('<Fill>HERE</Fill>', payload);
    return res;
  }

  // heuristics to pretty print person name
  function prettyPrintName( n, friendly ) {
    var res = '', fn, ln;
    if (n) {
      if (n.LastName) {
        res = n.LastName.toUpperCase() + (friendly ? '' : ' ');
      }
      ln = n.FirstName;
      if (ln) {
        ln = $.trim(ln);
        if (!/[a-z]/.test(ln)) { // all capital
          if (friendly) {
            res = ln.charAt(0).toUpperCase() + ln.substr(1).toLowerCase() + ' ' + res;
          } else {
            res += ln.charAt(0).toUpperCase() + ln.substr(1).toLowerCase();  
          }
        } else { // already ready
          if (friendly) { 
            res = ln.charAt(0).toUpperCase() + ln.substr(1) + ' ' + res;
          } else {
            res += ln.charAt(0).toUpperCase() + ln.substr(1);
          }
        }
      }
    } else {
      res = "Profile w/o name";
    }
    return res;
  }

  ////////////////////////////////////
  // Coach Evaluation Summary Table //
  ////////////////////////////////////

  // Turns Axis hash entry into table row
  function encodeAxisRow( d ) {
    return [
      d.For,
      (d.Score === 'x') ?  d.Score : d.Score + ' %'
      ]
  }

  // Generates summary table using d3
  // TODO: replace with radar view
  function genSummaryTable( table, data ) {
    var rows, cells;

    // table rows maintenance
    rows = table.select('tbody').selectAll('tr').data(data.Axis);
    rows.enter().append('tr');
    rows.exit().remove();

    // cells maintenance
    cells = table.select('tbody').selectAll('tr').selectAll('td').data(encodeAxisRow);
    cells.text(function (d) { return d; }); // update
    cells.enter().append('td').text(function (d) { return d; }); // create
    cells.exit().remove(); // delete
  }

  ////////////////////////////////////
  // Coach Evaluation Details Table //
  ////////////////////////////////////

  function encodeDetailsRow( d, starter ) {
    var row;
    if (starter) {
      row = new Array(4);
      row[0] = starter;
      row[d.Fit] = d.For;
    } else {
      row = new Array(3);
      row[d.Fit - 1] = d.For;
    }
    return row;
  }

  function encodeDetailsAxis( d, accu ) {
    var i;
    if ($.isArray(d.Skills)) {
      for (i= 0; i < d.Skills.length; i++) {
        if (i === 0) {
          accu.push(encodeDetailsRow(d.Skills[i], [d.For, d.Skills.length]));
        } else {
          accu.push(encodeDetailsRow(d.Skills[i]));
        }
      }
    } else if (d.Skills) { // assumes single Hash
      accu.push(encodeDetailsRow(d.Skills, d.For));
    }
    return accu;
  }

  function encodeDetailsTable( d ){
    var accu = [], i;
    if ($.isArray(d)) {
      for (i= 0; i < d.length; i++) {
        encodeDetailsAxis( d[i], accu )
      }
    } else {
        encodeDetailsAxis( d, accu )
    }
    return accu;
  }

  // Generates details table using d3
  function genDetailsTable( table, data ) {
    var rows, cells;

    // table rows maintenance
    rows = table.select('tbody').selectAll('tr').data(encodeDetailsTable(data.Details));
    rows.enter().append('tr');
    rows.exit().remove();

    // cells maintenance
    cells = table.select('tbody').selectAll('tr').selectAll('td').data(function(d) { return d; });
    cells.text(function (d) { return $.isArray(d) ? d[0] : d; }).attr('rowspan', function (d) { return $.isArray(d) ? d[1] : 1; }); // update
    cells.enter().append('td').text(function (d) { return $.isArray(d) ? d[0] : d; }).attr('rowspan', function (d) { return $.isArray(d) ? d[1] : 1; }); // create
    cells.exit().remove(); // delete
  }

  // host can be given as CSS selector string or as DOM node
  function genRadar( host, data, config ) {
    var plot = [[]];
    // conversion to {axis, value} format
    data.forEach(function(p, i) {
      var v = parseFloat(p.Score),
          d = { axis : p.For,
                value : isNaN(v) ? 0 : Math.round(v * 10) / 1000
              };
      if (isNaN(v)) {
        d.miss = true;
      }
      plot[0].push(d);
    });
    $axel.RadarChart.draw(host, plot, config);
  }

  function submitEvaluationError ( xhr, status, e ) {
    $('#cm-eva-name-var').text('...error while loading data...').parent().removeClass('cm-busy');
    reportAjaxError(xhr, status, e);
  }

  // Renders fit score, summary table and details table for each encoded dimension for given coach
  function submitEvaluationSuccess ( data, status, xhr ) {
    var i, prefix;
    COACH = data.Coach;
    if (COACH) {
      try {
        $('#cm-eva-summary').text(COACH.Summary || '');
        for (i = 0; i < COACH.Dimension.length; i++) {
          prefix = '#cm-eva-' + COACH.Dimension[i].Key;
          $(prefix + '-var').text(COACH.Dimension[i].Summary.Average + ' %');
          genRadar(prefix + '-summary', COACH.Dimension[i].Summary.Axis,
            {
            w: 300,
            h: 300,
            maxValue: 1,
            levels: 5,
            ExtraWidthX: 600,
            TranslateX: 280,
            format : '%',
            delta : 0
            });
          genDetailsTable(d3.select(prefix + '-details').style('display', 'table'), COACH.Dimension[i]);
          if (COACH['CV-Link']) {
            $('#cm-evaluation-cv-button').attr('href', COACH['CV-Link']).show();
          } else {
            $('#cm-evaluation-cv-button').hide();
          }
          if (COACH['CV-File']) {
            $('#cm-evaluation-pdf-button').attr('href', COACH['CV-File']).show();
          } else {
            $('#cm-evaluation-pdf-button').hide();
          }
          $(prefix + '-view').show();
        }
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
      }
      SLupdateButton(COACH.Id, 'cm-eva-shortlist-button');
      $('#cm-eva-name-var').text(prettyPrintName(COACH.Name, true)).parent().removeClass('cm-busy');
    } else { // nothing to show
      $('#cm-eva-name-var').text('...no data...').parent().removeClass('cm-busy');
    }
    // second part loading
    $('#cm-profile-part1').html('Loading coach profile');
    $('#cm-profile-part2').html('Loading coach profile');
    $.ajax({
      url : 'suggest/inspect/' + COACH.Id,
      type : 'post',
      async : false,
      data : '<Inspect Mode="embed"/>',
      dataType : 'html',
      cache : false,
      timeout : 50000,
      contentType : "application/xml; charset=UTF-8",
      success : submitInspectSuccessII,
      error : submitInspectErrorII
    });
    makeTOC();
    $('html, body').animate( { scrollTop : 0 }, 1000 );
  }

  function doEvaluateCoach (id, key, target, uuid) {
    var legacy = $('#cm-eva-shortlist-button'),
        table = target.closest('table');
    
    if (legacy.attr('data-coach') !== id) { // optimization : FIXME: cache in browser
      installOverlay('evaluation');
      $('#cm-eva-name-var').text('...loading...').parent().addClass('cm-busy');
      $('div.cm-eva-dim').hide();
      $.ajax({
        url : 'suggest/evaluation/' + id + (uuid ? '?uuid=' + uuid : ''),
        type : 'post',
        async : false,
        data : genPayloadFor(table.attr(id)),
        dataType : 'json',
        cache : false,
        timeout : 50000,
        contentType : "application/xml; charset=UTF-8",
        success : submitEvaluationSuccess,
        error : submitEvaluationError
      });
    } else {
      SLupdateButton(id, 'cm-eva-shortlist-button');
      installOverlay('evaluation');
    }
  }

  /////////////////////
  // Coach Inspector //
  /////////////////////

  function submitInspectError ( xhr, status, e ) {
    $('#cm-inspect-busy').hide();
    $('#cm-inspect-content').html('Error while loading');
    $('#cm-inspect-shortlist-button').attr('data-coach', '');
    reportAjaxError(xhr, status, e);
  }

  function submitInspectErrorII ( xhr, status, e ) {
    $('#cm-profile-part1').html('Failed to load more coach profile data');
    $('#cm-profile-part2').html('Failed to load more coach profile data');
  }

  function submitInspectSuccessII ( data, status, xhr ) {
    $('#cm-profile-part1').html($('#cm-profile-part1',data).html());
    $('#cm-profile-part2').html($('#cm-profile-part2',data).html());
  }

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

  function doInspectCoach (id, key, target) {
    var legacy = $('#cm-inspect-shortlist-button');
    if (legacy.attr('data-coach') !== id) { // optimization : FIXME: cache in browser
      $('#cm-inspect-busy').show();
      installOverlay('inspect');
      SLupdateButton(id, 'cm-inspect-shortlist-button');
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
      SLupdateButton(id, 'cm-inspect-shortlist-button');
      installOverlay('inspect');
    }
  }

  ////////////////////////////////////
  // Row (criteria, fit) generation //
  ////////////////////////////////////

  // Formats JSON response data :
  // - encodes numbers (could be done server side with json:literal) for column sorting
  // - pretty print names
  function formatData( d ) {
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
  }

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

  // Generates array for table row cells
  function encodeCriteriaRow( d, encodeCell ) {
    formatData(d);
    var res = [
      encodeCell('Name', d),
      d.Languages,
      d.Country,
      decodePerf(d),
      encodeCell('Action')
    ];
    return res;
  }

  // Generates array for table row cells
  function encodeFitRow( d, encodeCell ) {
    formatData(d);
    var res = [
      encodeCell('Name', d),
      d.Competence ? d.Competence + ' %' : undefined,
      d.Context ? d.Context + ' %' : undefined,
      decodePerf(d),
      d.Languages,
      d.Country,
      encodeCell('Action')
    ];
    return res;
  }

  // Generates array for table row cells
  function encodeShortListRow( d, encodeCell ) {
    var res = [
      encodeCell('Name', d),
      d.Competence ? d.Competence + ' %' : undefined,
      d.Context ? d.Context + ' %' : undefined,
      decodePerf(d),
      d.Languages,
      d.Country,
      encodeCell('Action')
    ];
    return res;
  }

  // Result table generation from Ajax JSON protocol response
  function submitSearchSuccess ( data, status, xhr ) {
    var tabname = data.Table,
        tabid = 'cm-' + tabname + '-results';
    DB.Variables = data.Variables;
    if (data.Coaches === undefined) {
      DB[tabname] = [];
    } else {
      DB[tabname] = $.isArray(data.Coaches) ? data.Coaches : [ data.Coaches ];
    }
    if (DB[tabname]) { // something to show
      $('#no-sample').hide();
      try {
        $axel.command.getCommand(tabname + '-table', tabid).execute(DB[tabname]); //.sort('Name');
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
      }
      $('#cm-' + tabname + '-competence-number').text(DB[tabname].length);
      if (tabname === 'fit') {
        $('#cm-' + tabname + '-languages-filter').val('');
        $('#cm-' + tabname + '-country-filter').val('');
      }
    } else { // nothing to show
      $('#no-sample').show();
      d3.selectAll('#cm-' + data.Table + '-results').style('display', 'none');
    }
    // Updates UI state (DEPRECATED ?)
    if (tabname === 'fit') {
      enableUI('cm-refine-button');
    }
    $('#cm-' + tabname + '-busy').hide();
  }

  // TODO: extend 'axel-save-done' to avoid parsing JSON twice
  function ajaxSearchSuccess ( data, status, xhr ) {
    submitSearchSuccess (data.payload.MatchResults);
    $('#cm-fit-busy').hide(); // use event.data
    $('#cm-criteria-busy').hide();
    $('#cm-criteria-collapsible-control').attr('disabled', null);
  }

  function submitByFitError ( xhr, status, e ) {
    $('#cm-fit-busy').hide();
    reportAjaxError(xhr, status, e);
  }

  function submitByFitRequest () {
    $('#cm-fit-busy').show();
    $.ajax({
      url : 'suggest/fit',
      type : 'post',
      async : true,
      data : genPayloadFor('cm-fit-results'),
      dataType : 'json',
      cache : false,
      timeout : 50000,
      contentType : "application/xml; charset=UTF-8",
      success : ajaxSearchSuccess,
      error : submitByFitError
    });
  }

  function submitByCriteriaError ( xhr, status, e )  {
    $('#cm-criteria-busy').hide();
    enableUI('cm-refine-button', 'cm-criteria-mid-button', 'cm-criteria-high-button'); // DEPRECATED
    reportAjaxError(xhr, status, e);
  }

  // DEPRECATED
  function submitByCriteria (event) {
    $('#cm-criteria-busy').show();
    disableUI('cm-criteria-mid-button', 'cm-criteria-high-button');
    $.ajax({
      url : 'suggest/criteria' + '?match=' + event.data.match,
      type : 'post',
      async : true,
      data : genPayloadFor('cm-criteria-results'),
      dataType : 'json',
      cache : false,
      timeout : 50000,
      contentType : "application/xml; charset=UTF-8",
      success : ajaxSearchSuccess,
      error : submitByCriteriaError
    });
  }

  function submitRefineByCriteria (event) {
    $('#cm-criteria-busy').show();
    disableUI('cm-refine-button');
    $.ajax({
      url : 'suggest/fit',
      type : 'post',
      async : true,
      data : genPayloadFor('cm-refine-criteria-results'),
      dataType : 'json',
      cache : false,
      timeout : 50000,
      contentType : "application/xml; charset=UTF-8",
      success : ajaxSearchSuccess,
      error : submitByCriteriaError
    });
  }

  ///////////////
  // Analytics //
  ///////////////

  function doButtonAnalytics (event) {
    var n = $(event.target),
        addr = n.attr("data-analytics-controller"),
        type = n.attr('id');
    if (UUID && addr && type) {
      $.ajax({
        url : addr + '/'+ UUID,
        type : 'post',
        data :  { 'action' : COACH.Id, 'target' : type },
        cache : false,
        timeout : 20000
      });
    }
  }

  ////////////////
  // Short List //
  ////////////////

  function SLupdateButton (id, target) {
    $('#' + target).attr('data-coach', id);
    if (SLcontains(id)) {
      disableUI(target);
    } else {
      enableUI(target);
    }
  }

  // Checks if shortlist already contains a coach
  function SLcontains (id) {
    for (var i = 0; i < SHORTLIST.length; i++) {
      if (SHORTLIST[i].Id === id) {
        return true;
      }
    }
    return false;
  }

  function doRemoveCoach (id, key, target) {
    var i;
    for (var i = 0; i < SHORTLIST.length; i++) {
      if (SHORTLIST[i].Id === id) {
        SHORTLIST.splice(i, 1);
      }
    }
    try {
      $axel.command.getCommand('shortlist-table', 'cm-shortlist').execute(SHORTLIST);
      updateShortlistRowStatus('fit', id, false);
      updateShortlistRowStatus('criteria', id, false);
    } catch (e) {
      alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
    }
  }

  // sets 'shortlist' to status (true or false) on cur coach row of table
  function updateShortlistRowStatus(table, cur, status) {
    d3.select('#cm-' + table + '-results').select('tbody').selectAll('tr').filter(function(d) { return d.Id === cur; }).classed('shortlist', status);
  }

  function handleShortListPlus (ev) {
    var jtarget = $(ev.target),
        cur = jtarget.attr('data-coach'),
        key =  DB_CUR || 'fit',
        TABLE,
        i, found, clone;
        
    for (var i = 0; i < SHORTLIST.length; i++) {
      if (SHORTLIST[i].Id === cur) {
        return; // already in it
      }
    }
    // trick: actually 'fit' table contains all coaches with scores
    // so it is always used as a source for the shortlist
    TABLE = DB[key];
    for (var i = 0; i < TABLE.length; i++) {
      if (TABLE[i].Id === cur) {
        clone = {}; // makes a copy
        $axel.extend(clone, TABLE[i]);
        clone.SL = true;
        SHORTLIST.push(clone);
        break;
      }
    }
    try {
      $axel.command.getCommand('shortlist-table', 'cm-shortlist').execute(SHORTLIST);
      $('#cm-eva-shortlist-button').attr('disabled','disabled');
      $('#cm-inspect-shortlist-button').attr('disabled','disabled');
      updateShortlistRowStatus('fit', cur, true);
      updateShortlistRowStatus('criteria', cur, true);
    } catch (e) {
      alert('Exception [' + e.name + ' / ' + e.message + '] please contact application administrator !');
    }
  }

  /////////////
  // Handout //
  /////////////

  // Serializes as XML coaches in short list
  function genShortList( table ) {
    return '<ShortList>' +
      SHORTLIST.reduce(
            function(prev, cur, index, array) {
              return prev + '<CoachRef>' + cur.Id  + '</CoachRef>';
            }, '') + '</ShortList>'
  }
  
  function submitHandoutError ( xhr, status, e ) {
    $('#cm-handout-busy').hide();
    $('#cm-handout-content').html('Error while loading');
    reportAjaxError(xhr, status, e);
  }

  function submitHandoutSuccess ( data, status, xhr ) {
    $('#cm-handout-busy').hide();
    $('#cm-handout-content').html(data);
    $('script.cm-radar').each( function() {
      var data = JSON.parse($(this).text()),
          graph = $(this).next('div.cm-radar').get(0);
      genRadar(graph, data.Axis,
        {
        w: 200,
        h: 200,
        maxValue: 1,
        levels: 5,
        ExtraWidthX: 100,
        TranslateX: 50,
        format : '%',
        delta : 0
        });
      // empritical (!)
      $(graph).find('g.axis:eq(1) > text').attr('transform', 'translate(-130,50) rotate(270)');
      $(graph).find('g.axis:eq(3) > text').attr('transform', 'translate(340,-140) rotate(90)');
      }
    );
  }

  function showHandout (ev) {
    installOverlay('handout');
    $('#cm-handout-content').html('');
    $('#cm-handout-busy').show();
    $.ajax({
      url : 'suggest/handout' + (UUID ? '?uuid=' + UUID : ''),
      type : 'post',
      async : false,
      data : genPayloadFor('cm-handout'),
      dataType : 'html',
      cache : false,
      timeout : 50000,
      contentType : "text/html; charset=UTF-8",
      success : submitHandoutSuccess,
      error : submitHandoutError
    });
  }

  // Hides fixed menus to reveal the overlay div
  function installOverlay (name) {
    $('#cm-search-view').hide();
    $('#cm-' +name + '-view').show();
    if (name === 'handout') {
      $('div.fixed-top').hide();
      $('body').attr('id', ''); // remove padding-top
    }
  };

  // Restore fixed menus and hide the overlay div
  function uninstallOverlay (name) {
    if (name === 'handout') {
      $('div.fixed-top').show();
      $('body').attr('id','c-skip-header');
    }
    $('#cm-search-view').show();
    $('#cm-' +name + '-view').hide();
  };

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

  // Loads and generates search by criteria formular (only once)
  function initCriteriaSearch (event) {
    var ed = $axel.command.getEditor('cm-criteria-edit');
    if (ed) {
      ed.transform();
      // synchronous loading at the moment
      if ($axel('#cm-criteria-edit').transformed()) {
        enableUI('cm-criteria-mid-button', 'cm-criteria-high-button');
      } else {
        $('#cm-criteria-tab-tab').one('click', initCriteriaSearch);
      }
    }
  }

  function init() {
    // deferred tabs
    $('#cm-criteria-collapsible-control').attr('disabled', 'disabled');
    $('#cm-criteria-collapsible-control').one('click', initCriteriaSearch);
    // commands
    $('#cm-eva-shortlist-button').click(handleShortListPlus);
    $('#cm-inspect-shortlist-button').click(handleShortListPlus);
    $('#cm-shortlist-handout-button').click(showHandout);
    $('#cm-refine-button').bind('click', submitRefineByCriteria);
    // analytics
    $('#cm-evaluation-pdf-button').bind('click', doButtonAnalytics);
    $('#cm-evaluation-cv-button').bind('click', doButtonAnalytics);
    UUID = $($.parseXML($("#cm-service-envelope").text())).find('UUID').text();
    // pre-loading
    submitByFitRequest();
  }

  jQuery(function() { init(); });
  
  // records new commands before page ready handler
  $axel.command.makeTableCommand('criteria', encodeCriteriaRow, GENCRITERIA);
  $axel.command.makeTableCommand('fit', encodeFitRow, GENFIT);
  $axel.command.makeTableCommand('shortlist', encodeShortListRow, GENSHORTLIST);
}());
