(function () {

  var WHO;
  var HOST;
  var STATUS = [ '_undef', 'Submit', 'Reject', 'Remove', 'Accredit' ];
  var WSTATUS = [ '_undef', 'Activated', 'Deactivated' ];
  var SELACC_SUB = '<select style="width:180px" id="sel-acceptance-#"><option value="1">Submitted</option><option value="2">Reject</option><option value="4">Accept</option></select>';
  var SELACC_ACC = '<select style="width:180px" id="sel-acceptance-#"><option value="3">Remove</option><option value="4" selected="true">Accepted</option></select>';
  var SELACC_DEL = '<select style="width:180px" id="sel-acceptance-#"><option value="1">Submit</option><option value="2">Reject</option><option value="3">Remove</option><option value="4">Accept</option></select>';
  var SELWORK = '<select style="width:100px" id="sel-working-status-#"><option value="1">Activated</option><option value="2">Deactivated</option></select>';
  var CONTACTS, _TMP_CONTACTS = [];
  var SELCONTACTS;
  var FINISHED = { 'applicant': false, 'accepted': false, 'deleted': false };
  var FILTER = '';
  var TIMEOUT = {};

  // Table columns model - could be packaged in JSON reponse to localize server-side
  var GENUSER = {
    Notes : {
      yes : '<a>yes</a>',
      no : '<a>---</a>',
      editor : 'cm-update-host-extra-editor',
      resource : '$_/hosts/$H/comments?table=$#',
      template : 'templates/host/comments?goal=update'
    },
    Name : {
      yes : '*',
      open : '$_',
      ascending : function(a, b) { return d3.ascending(a.Name.LastName, b.Name.LastName); },
      descending :  function(a, b) { return d3.descending(a.Name.LastName, b.Name.LastName); },
      filter : incrementalFilterFunc
    },
    AccDate : {
      yes : '.',
      ascending : function(a, b) { return d3.ascending(a.AccDate, b.AccDate); },
      descending :  function(a, b) { return d3.descending(a.AccDate, b.AccDate); }
    },
    WorkDate : {
      yes : '.'
    },
    SaveApplicant : {
      button : '<button class="btn btn-primary">Save</button>',
      callback : doSaveApplicant
    },
    SaveAccepted : {
      button : '<button class="btn btn-primary">Save</button>',
      callback : doSaveAccepted
    },
    SaveDeleted : {
      button : '<button class="btn btn-primary">Save</button>',
      callback : doSaveDeleted
    }
  };
  
  // Special filtering function taking into account incremental loading protocol
  function incrementalFilterFunc(d, key, value) {
    var res = true;
    if (d[key]) {
      if (typeof d[key] === 'object') {
        var serial = '';
        for (var k in d[key]) {
          if (d[key].hasOwnProperty(k)) {
            serial += ' ' + d[key][k];
          }
        }
        res = serial.toUpperCase().indexOf(value) !== -1;
      } else {
        res = d[key].toUpperCase().indexOf(value) !== -1;
      }
    }
    return res;
  }
  
  // turns on/off loading feedback on tables
  function switchLoading( state, table ) {
    if (table) {
      if (state === 'on') {
        $('#cm-host-' + table + '-results').addClass('loading');
      } else {
        $('#cm-host-' + table + '-results').removeClass('loading');
      }
    } else {
      switchLoading(state, 'accepted');
      switchLoading(state, 'deleted');
    }
  }

  function genTag(tag,value) {
    return '<' + tag + '>' + value + '</' + tag + '>';
  }

  function genDate() {
    // date (YYYY-MM-DD)
    var today = new Date();
    var dd = today.getDate();
    var mm = today.getMonth()+1; //January is 0!

    var yyyy = today.getFullYear();
    if(dd < 10)
      dd='0'+dd
    if(mm < 10)
      mm='0'+mm

    return yyyy+'-'+mm+'-'+dd;
  }

  function genURLForHost(controller) {
    return 'hosts/' + HOST + '/' + controller;
  }

  function genURLForUserAndHost(controller) {
    return WHO + '/' + genURLForHost(controller);
  }

  function genPayloadForUpdate(uid, selacc, selcont, selwork) {
    var uid = genTag('CoachRef', uid),
        acc = genTag('AccreditationRef', selacc),
        cont = (selcont != '0') ? genTag('ContactRef', selcont) : '',
        work = (selwork && (selwork != '0')) ? genTag('WorkingRankRef', selwork) : '';
    return genTag('Update', uid + acc + cont + work);
  }

  function switchDisplayTable(name) {
    var table = '#cm-host-' + name + '-results';
    if ($(table).find('tbody').find('tr').length == 0)
      d3.select(table).style('display', 'none');
    else
      d3.select(table).style('display', 'table');
  }

  // Forwards $.ajax errors to application global error handler
  function jqForwardError ( xhr, status, e )  {
    $('#cm-mgt-busy').hide();
    $('body').trigger('axel-network-error', { xhr : xhr, status : status, e : e });
    switchLoading('off');
  }
  
  function jqRestoreAndForwardError ( tr, xhr, status, e ) {
    jqForwardError(xhr, status, e);
    tr.find('button').show();
    tr.find('.c-busy').parent().remove();
  }

  // Caching utility to decode Ajax response with contacts and generate a SELCONTACTS string 
  // to easily instantiate contacts drop down list into table rows
  function gatherContacts ( data, status, xhr ) {
    CONTACTS = data;
    SELCONTACTS = '<select style="width:120px" id="sel-contact-#"><option value="0">No Contact</option>';
    if (CONTACTS.Users !== undefined) {
      if (CONTACTS.Users instanceof Array) {
        for (i in CONTACTS.Users) {
          var opt = '<option value="' + CONTACTS.Users[i].Id+ '">' + CONTACTS.Users[i].Name.FirstName + ' ' + CONTACTS.Users[i].Name.LastName + '</option>';
          SELCONTACTS += opt;
        }
      } else {
        var opt = '<option value="' + CONTACTS.Users.Id+'">' + CONTACTS.Users.Name.FirstName + ' ' + CONTACTS.Users.Name.LastName + '</option>';
        SELCONTACTS += opt;
      }
    }
    SELCONTACTS += '</select>';
  }

  ////////////
  // Tables //
  ////////////

  // Expects: data.Table (name of table to redraw), data.Users (rows)
  function createTable ( data, status, xhr, isInc, update ) {
    var DB = (data.Users === undefined || $.isArray(data.Users)) ? data.Users : [ data.Users ],
        tabname = data.Table,
        tabid = 'cm-' + tabname + '-results';

    if (DB) { // something to show
      try {
        $axel.command.getCommand(tabname + '-table', tabid).execute(DB, update);
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] please contact an application administrator !');
      }
      d3.selectAll('#' +  tabid + ' tbody').style('display', 'table-row-group');
      $('span.cm-' + tabname + '-counter').text($('#' + tabid + ' tr').length + (isInc ? ' of ...' : ''));
      if (isInc) {
        $('#cm-' + tabname + '-complete').hide();
      } else {
        $('#cm-' + tabname + '-complete').show();
      }
      $('#' + tabid + ' input').val(FILTER);
    } else if (update) {
      FINISHED[tabname.replace('host-', '')] = true; // tabname host- convention
      $('span.cm-' + tabname + '-counter').text($('#' + tabid + ' tr').length);
      $('#cm-' + tabname + '-complete').show();
    } else if (!update && (!DB || !FILTER)) { // nothing to show else header if filtering
      d3.selectAll('#' +  tabid + ' tbody').style('display', 'none');
    }
    $('#c-busy').hide();
  }

  // Adds new rows to table
  function growTable ( data, status, xhr ) {
    createTable(data, status, xhr, true, $('#cm-' + data.Table + '-results tr').length > 1);
    switchLoading('off');
  }

  // Regenerate table from scratch
  function reloadTable ( data, status, xhr ) {
    createTable(data, status, xhr, true, false);
    switchLoading('off');
  }

  function encodeApplicantRow( d, encodeCell ) {
    var acc = d.AccDate,
        s3 = SELCONTACTS.replace('#', d.Id);

    s3 = s3.replace('"'+ d.Contact +'"', '"'+ d.Contact +'" selected="true"');
    d.Name.LastName = d.Name.LastName.toUpperCase(); // side effect for sorting
    return [
      encodeCell('Name', d.Name ? d.Name.LastName + ' ' + d.Name.FirstName : 'Anonymous (' + d.Id + ')'),
      encodeCell('AccDate', acc.substring(0,10)),
      SELACC_SUB,
      s3,
      encodeCell('SaveApplicant')
    ];
  }

  function encodeAcceptedRow( d, encodeCell ) {
    var acc = d.AccDate, 
        wor = d.WorkDate,
        s1 = SELACC_ACC.replace('#', d.Id),
        s2 = SELWORK.replace('#', d.Id),
        s3 = SELCONTACTS.replace('#', d.Id);

    s1 = s1.replace('Accepted', 'Accepted ('+ acc.substring(0,10) +')');
    s2 = s2.replace('"'+ d.WorkingStatus +'"', '"'+ d.WorkingStatus +'" selected="true"');
    if (d.wor !== undefined) {
      if (d.WorkingStatus == '1') {
        s2 = s2.replace('Activated', 'Activated ('+ wor.substring(0,10) +')');
      } else {
        s2 = s2.replace('Deactivated', 'Deactivated ('+ wor.substring(0,10) +')');
      }
    }
    s3 = s3.replace('"'+ d.Contact +'"', '"'+ d.Contact +'" selected="true"');
    d.Name.LastName = d.Name.LastName.toUpperCase(); // side effect for sorting
    return [
      encodeCell('Name', d.Name ? d.Name.LastName + ' ' + d.Name.FirstName : 'Anonymous (' + d.Id + ')'),
      encodeCell('Notes', d),
      s1, s2, s3,
      encodeCell('SaveAccepted')
    ];
  }

  function encodeDeletedRow( d, encodeCell ) {
    var acc = d.AccDate, 
        wor = d.WorkDate,
        s1 = SELACC_DEL.replace('#', d.Id),
        s2 = (d.WorkingStatus == '1') ? 'Activated' : 'Deactivated',
        s3 = SELCONTACTS.replace('#', d.Id);
    
    s1 = s1.replace('"'+ d.HostStatus +'"', '"'+ d.HostStatus +'" selected="true"');
    if (d.HostStatus == '2') {
      s1 = s1.replace('Reject', 'Reject ('+ acc.substring(0,10) +')');
    } else {
      s1 = s1.replace('Remove', 'Remove ('+ acc.substring(0,10) +')');
    }
    s3 = s3.replace('"'+ d.Contact +'"', '"'+ d.Contact +'" selected="true"');
    d.Name.LastName = d.Name.LastName.toUpperCase(); // side effect for sorting
    return [
      encodeCell('Name', d.Name ? d.Name.LastName + ' ' + d.Name.FirstName : 'Anonymous (' + d.Id + ')'),
      encodeCell('Notes', d),
      s1, s2, s3,
      encodeCell('SaveDeleted')
    ];
  }

  // handle save button from applications table - target is save button jquery singleton
  function doSaveApplicant(id, key, target) {
    var tr = target.closest('tr'),
        td = target.closest('td'),
        selacc = tr.find('[id*="sel-acceptance"]').val(),
        selcont = tr.find('[id*="sel-contact"]').val(); // PB: que devient l'ancien working status obtenu ailleurs ?!

    target.hide();
    td.append('<div style="margin: 0 auto; width: 32px"><p class="c-busy" style="height:32px;"/></div>');

    $.ajax({
      url : genURLForUserAndHost('update'),
      dataType : 'xml',
      data : genPayloadForUpdate(id, selacc, selcont),
      type : 'POST',
      contentType : "application/xml; charset=UTF-8",
      success : saveApplicantSuccess,
      error : function(xhr, status, e) { jqRestoreAndForwardError(tr, xhr, status, e); }
    });
  }

  // handle save button from accepted table - target is save button jquery singleton
  function doSaveAccepted(id, key, target) {
    var tr = target.closest('tr'),
        td = target.closest('td'),
        selacc = tr.find('[id*="sel-acceptance"]').val(),
        selcont = tr.find('[id*="sel-contact"]').val(),
        selwork = tr.find('[id*="sel-working-status"]').val();

    target.hide();
    td.append('<div style="margin: 0 auto; width: 32px"><p class="c-busy" style="height:32px;"/></div>');

    $.ajax({
      url : genURLForUserAndHost('update'),
      dataType : 'xml',
      data : genPayloadForUpdate(id, selacc, selcont, selwork),
      type : 'POST',
      contentType : "application/xml; charset=UTF-8",
      success : saveAcceptedSuccess,
      error : function(xhr, status, e) { jqRestoreAndForwardError(tr, xhr, status, e); }
    });
  }

  // handle save button from deleted table - target is save button jquery singleton
  function doSaveDeleted(id, key, target) {
    var tr = target.closest('tr'),
        td = target.closest('td'),
        selacc = tr.find('[id*="sel-acceptance"]').val(),
        selcont = tr.find('[id*="sel-contact"]').val(),
        selwork = tr.find('[id*="sel-working-status"]').val();

    target.hide();
    td.append('<div style="margin: 0 auto; width: 32px"><p class="c-busy" style="height:32px;"/></div>');

    $.ajax({
      url : genURLForUserAndHost('update'),
      dataType : 'xml',
      data : genPayloadForUpdate(id, selacc, selcont, selwork),
      type : 'POST',
      contentType : "application/xml; charset=UTF-8",
      success : saveDeletedSuccess,
      error : function(xhr, status, e) { jqRestoreAndForwardError(tr, xhr, status, e); }
    });
  }

  // Decodes Ajax success response after a row save
  function saveApplicantSuccess(data, status, xhr) {
    var accredit = $(data).find('New').text(),
        id = $(data).find('Id').text(),
        tabctrl = $axel.command.getCommand('host-applicant-table', 'cm-host-applicant-results'),
        row;

    if (accredit != '1') { // no more in applicant table
      if (accredit == '4')
        FINISHED['accepted'] = false;
      else
        FINISHED['deleted'] = false;
      tabctrl.removeRowById(id);
      switchDisplayTable('applicant');
    } else {
      row = $(tabctrl.getRowById(id));
      row.find('button').show();
      row.find('.c-busy').parent().remove();
    }
  }

  // Decodes Ajax success response after a row save
  function saveAcceptedSuccess(data, status, xhr) {
    var accredit = $(data).find('New').text(),
        id = $(data).find('Id').text(),
        tabctrl = $axel.command.getCommand('host-accepted-table', 'cm-host-accepted-results'),
        row;

    if (accredit != '4') { // no more in accepted table
      FINISHED['deleted'] = false
      tabctrl.removeRowById(id);
      switchDisplayTable('accepted');
    } else {
      row = $(tabctrl.getRowById(id));
      row.find('button').show();
      row.find('.c-busy').parent().remove();
    }
  }

  // Decodes Ajax success response after a row save
  function saveDeletedSuccess(data, status, xhr) {
    var accredit = $(data).find('New').text(),
        id = $(data).find('Id').text(),
        tabctrl = $axel.command.getCommand('host-deleted-table', 'cm-host-deleted-results'),
        row;

    if (accredit != '2' && accredit != 3) { // no more in deleted table
      if (accredit == '1') // go to applicants table
        FINISHED['applicant'] = false
      else // go to accepted table
        FINISHED['accepted'] = false
      tabctrl.removeRowById(id);
      switchDisplayTable('deleted');
    } else {
      row = $(tabctrl.getRowById(id));
      row.find('button').show();
      row.find('.c-busy').parent().remove();
    }
  }

  function getAllApplicants() {
    $.ajax({
      url : genURLForHost('acceptances?key=1'),
      dataType : 'json',
      type : 'get',
      timeout : 50000,
      async : false,
      contentType : "application/json; charset=UTF-8",
      success : createTable,
      error : jqForwardError
    });
  }

  function getAllAccepted(a, nb, ln) {
    $('#c-busy').show()
    if (a === 1) { // reload new table
      FINISHED['accepted'] = false;
    }
    ln = ln ? '&ln=' + ln : '';
    switchLoading('on', 'accepted');
    $.ajax({
      url : genURLForHost('acceptances?key=4&a=' + a + '&nb=' + nb + ln),
      dataType : 'json',
      type : 'get',
      timeout : 50000,
      async : false,
      contentType : "application/json; charset=UTF-8",
      success : a === 1 ? reloadTable : growTable,
      error : jqForwardError
    });
    DEACTIVATED = true
  }

  function getAllDeleted(a, nb, ln) {
    $('#c-busy').show()
    if (a === 1) { // reload new table
      FINISHED['deleted'] = false;
    }
    ln = ln ? '&ln=' + ln : '';
    switchLoading('on', 'deleted');
    $.ajax({
      url : genURLForHost('acceptances?a=' + a + '&nb=' + nb + ln),
      dataType : 'json',
      type : 'get',
      timeout : 50000,
      async : false,
      contentType : "application/json; charset=UTF-8",
      success : a === 1 ? reloadTable : growTable,
      error : jqForwardError
    });
    DEACTIVATED = true
  }

  // initializes coach management tab
  function lazyInit() {
    GENUSER.Notes.resource = GENUSER.Notes.resource.replace('$H', HOST);
    // pre-loading contacts
    $.ajax({
      url : genURLForHost('contact-persons.json'),
      dataType : 'json',
      type : 'get',
      async : false, // mandatory
      contentType : "application/json; charset=UTF-8",
      success : gatherContacts,
      error : jqForwardError
    });
    // pre-loading applicants table
    getAllApplicants();
    // horizontal tab selectors
    $('#nav-accr a').click(
      // regenerates tables to show coaches with updated acceptance status
      function (e) {
        FILTER = ''
        var jnode = $(this),
            pane= $(jnode.attr('href'));
        if (jnode.attr('href') == "#c-pane-applicant") {
          getAllApplicants();
        } else if (jnode.attr('href') == "#c-pane-accepted") {
          getAllAccepted(1, 50);
  	    } else if (jnode.attr('href') == "#c-pane-deleted") {
          getAllDeleted(1, 50);
        }
      }
    );
    $(window).scroll(
      function () {
        if ($('#cm-host-accepted-results').height() > 0 && !FINISHED['accepted']) {
          var over = $(document).height() <= $(window).scrollTop() + $(window).height()
          if (over && DEACTIVATED) {
            DEACTIVATED = false;
            var hm = $('#cm-host-accepted-results tr').length;
            getAllAccepted(hm, 50, FILTER);
          }
        }
        if ($('#cm-host-deleted-results').height() > 0 && !FINISHED['deleted']) {
          var over = $(document).height() <= $(window).scrollTop() + $(window).height()
          if (over && DEACTIVATED) {
            DEACTIVATED = false;
            var hm = $('#cm-host-deleted-results tr').length;
            getAllDeleted(hm, 50, FILTER);
          }
        }
      }
    );
  }

  function filterUsers (table) {
    FILTER = $('#cm-host-' + table + '-results th > input').val(); // limitation : 1 filterable column
    if (table === 'accepted') {
      getAllAccepted(1, 50, FILTER);
    } else if (table === 'deleted') {
      getAllDeleted(1, 50, FILTER);
    }
  }

  // temporize filtering by 1 second
  function lazyFilterUsers(ev) {
    var that = this,
        key = ev.data.table;
    if (TIMEOUT[key]) {
      clearTimeout(TIMEOUT[key]);
    }
    TIMEOUT[key] = setTimeout(function () {
      filterUsers(key);
    }, 1000);
  }

  function init() {
    $('#c-pane-deleted').after('<div style="margin: 0 auto; width: 32px"><p id="c-busy" style="height:32px;"/></div>');
    // get parameters for async. calls
    WHO = $('#cm-host-applicant-results').attr('who');
    HOST = $('#cm-host-applicant-results').attr('host');
    if (HOST) { // TODO: hard coded tab id
      $('*[data-toggle="tab"][href="#cm-host-1-coach-man"]').one('show', lazyInit);
      $('table[id*="cm-host-accepted-results"]').on('keyup', { 'table' : 'accepted' }, lazyFilterUsers);
      $('table[id*="cm-host-deleted-results"]').on('keyup', { 'table' : 'deleted' }, lazyFilterUsers);
    }
  }

  jQuery(function() { init(); });

  // records new commands before page ready handler
  $axel.command.makeTableCommand('host-applicant', encodeApplicantRow, GENUSER);
  $axel.command.makeTableCommand('host-accepted', encodeAcceptedRow, GENUSER);
  $axel.command.makeTableCommand('host-deleted', encodeDeletedRow, GENUSER);
}());

$(function(){
	$('table[id*="cm-host-"]').each(function() {
		if($(this).find('thead').length > 0 && $(this).find('th').length > 0) {
			// Clone <thead>
			var $w	   = $(window),
				$t	   = $(this),
				$thead = $t.find('thead').clone(),
				$col   = $t.find('thead, tbody').clone();
			$thead.find('input').remove()
			// Add class, remove margins, reset width and wrap table
			$t
			.addClass('sticky-enabled')
			.css({
				margin: 0,
				width: '100%'
			}).wrap('<div class="sticky-wrap" />');

			if($t.hasClass('overflow-y')) $t.removeClass('overflow-y').parent().addClass('overflow-y');

			// Create new sticky table head (basic)
			$t.after('<table class="sticky-thead table table-bordered" />');

			// If <tbody> contains <th>, then we create sticky column and intersect (advanced)
			if($t.find('tbody th').length > 0) {
				$t.after('<table class="sticky-col" /><table class="sticky-intersect" />');
			}

			// Create shorthand for things
			var $stickyHead  = $(this).siblings('.sticky-thead'),
				$stickyCol   = $(this).siblings('.sticky-col'),
				$stickyInsct = $(this).siblings('.sticky-intersect'),
				$stickyWrap  = $(this).parent('.sticky-wrap');

			$stickyHead.append($thead);

			$stickyCol
			.append($col)
				.find('thead th:gt(0)').remove()
				.end()
				.find('tbody td').remove();

			$stickyInsct.html('<thead><tr><th>'+$t.find('thead th:first-child').html()+'</th></tr></thead>');

			// Set widths
			var setWidths = function () {
					$t
					.find('thead th').each(function (i) {
						$stickyHead.find('th').eq(i).width($(this).outerWidth());
					})
					.end()
					.find('tr').each(function (i) {
						$stickyCol.find('tr').eq(i).height($(this).height());
					});
					// Set width of sticky table head
					$stickyHead.width($t.width());

					// Set width of sticky table col
					$stickyCol.find('th').add($stickyInsct.find('th')).width($t.find('thead th').width())
				},
				repositionStickyHead = function () {
					if($t.height() <= $stickyWrap.height()) {
						// If it is not overflowing (basic layout)
						// Position sticky header based on viewport scrollTop
						if($w.scrollTop() > $t.offset().top - 90 && $t.is(':visible')) {
							// When top of viewport is in the table itself
              $stickyHead.add($stickyInsct).css({position: 'fixed', opacity: 1,top: 90, left: $t.offset().left});
						} else {
							// When top of viewport is above or below table
              $stickyHead.add($stickyInsct).css({opacity: 0, top: 0});
						}
					}
				}

			$t.parent('.sticky-wrap').scroll($.debounce(100, function() {
				repositionStickyHead();
			}));

			$w
			.load(setWidths)
			.resize($.debounce(250, function () {
				setWidths();
				repositionStickyHead();
			}))
			.scroll($.debounce(150, function() {
                                setWidths();
				repositionStickyHead();
                        }));

      $stickyHead.css({'pointer-events': 'none'});
		}
	});
});

/*!
 * jQuery throttle / debounce - v1.1 - 3/7/2010
 * http://benalman.com/projects/jquery-throttle-debounce-plugin/
 *
 * Copyright (c) 2010 "Cowboy" Ben Alman
 * Dual licensed under the MIT and GPL licenses.
 * http://benalman.com/about/license/
 *
 * See docs/third-party.md
 */
(function(window,undefined){
  '$:nomunge'; // Used by YUI compressor.

  // Since jQuery really isn't required for this plugin, use `jQuery` as the
  // namespace only if it already exists, otherwise use the `Cowboy` namespace,
  // creating it if necessary.
  var $ = window.jQuery || window.Cowboy || ( window.Cowboy = {} ),

    // Internal method reference.
    jq_throttle;

  // Method: jQuery.throttle (see docs/third-party.md)
  $.throttle = jq_throttle = function( delay, no_trailing, callback, debounce_mode ) {
    // After wrapper has stopped being called, this timeout ensures that
    // `callback` is executed at the proper times in `throttle` and `end`
    // debounce modes.
    var timeout_id,

      // Keep track of the last time `callback` was executed.
      last_exec = 0;

    // `no_trailing` defaults to falsy.
    if ( typeof no_trailing !== 'boolean' ) {
      debounce_mode = callback;
      callback = no_trailing;
      no_trailing = undefined;
    }

    // The `wrapper` function encapsulates all of the throttling / debouncing
    // functionality and when executed will limit the rate at which `callback`
    // is executed.
    function wrapper() {
      var that = this,
        elapsed = +new Date() - last_exec,
        args = arguments;

      // Execute `callback` and update the `last_exec` timestamp.
      function exec() {
        last_exec = +new Date();
        callback.apply( that, args );
      };

      // If `debounce_mode` is true (at_begin) this is used to clear the flag
      // to allow future `callback` executions.
      function clear() {
        timeout_id = undefined;
      };

      if ( debounce_mode && !timeout_id ) {
        // Since `wrapper` is being called for the first time and
        // `debounce_mode` is true (at_begin), execute `callback`.
        exec();
      }

      // Clear any existing timeout.
      timeout_id && clearTimeout( timeout_id );

      if ( debounce_mode === undefined && elapsed > delay ) {
        // In throttle mode, if `delay` time has been exceeded, execute
        // `callback`.
        exec();

      } else if ( no_trailing !== true ) {
        // In trailing throttle mode, since `delay` time has not been
        // exceeded, schedule `callback` to execute `delay` ms after most
        // recent execution.
        //
        // If `debounce_mode` is true (at_begin), schedule `clear` to execute
        // after `delay` ms.
        //
        // If `debounce_mode` is false (at end), schedule `callback` to
        // execute after `delay` ms.
        timeout_id = setTimeout( debounce_mode ? clear : exec, debounce_mode === undefined ? delay - elapsed : delay );
      }
    };

    // Set the guid of `wrapper` function to the same of original callback, so
    // it can be removed in jQuery 1.4+ .unbind or .die by using the original
    // callback as a reference.
    if ( $.guid ) {
      wrapper.guid = callback.guid = callback.guid || $.guid++;
    }

    // Return the wrapper function.
    return wrapper;
  };

  // Method: jQuery.debounce (see docs/third-party.md)
  $.debounce = function( delay, at_begin, callback ) {
    return callback === undefined
      ? jq_throttle( delay, at_begin, false )
      : jq_throttle( delay, callback, at_begin !== false );
  };

})(this);
