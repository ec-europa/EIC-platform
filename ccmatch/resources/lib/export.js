(function () {

  function errorCb (node, xhr, status, e) {
    $('body').trigger('axel-network-error', { xhr : xhr, status : status, e : e });
    node.removeAttr('disabled');
  }

  function signatureSuccessCb (node, response, status, xhr) {
    node.replaceWith($('success > date', xhr.responseXML).text());
  }

  function handleClick (ev) {
    var n = $(ev.target),
        p = n.parents('tr');
    if (n.text() === 'sign') {
      doSignCase(p.attr('data-case'), p.children('td:nth-child(3)').text(),n);
    }
  }

  function doSignCase ( caseNo, acro, node ) {
    var date = $('input.year').val(),
        _n = node;
    if (date === '') {
      alert('You must enter a grant agreement signature date in the parameters first !');
    } else if (confirm('Do you confirm you want to set the grant agreement signature for ' + acro + ' to ' + date + ' ?')) {
      node.attr('disabled', 'disable');
      $.ajax({
        url : '../../cases/' + caseNo + '/sign',
        type : 'post',
        data : $axel('#editor').xml(),
        dataType : 'xml',
        contentType: 'application/xml; charset=UTF-8',
        cache : false,
        timeout : 50000,
        success : function (response, status, xhr) { signatureSuccessCb(_n, response, status, xhr) },
        error : function (xhr, status, e) { errorCb(_n, xhr, status, e) },
        async : false
      });
    }
  }

  function init() {
    if (ExcellentExport) {
      $('#results-export').children('a').first().click(function() {
         return ExcellentExport.excel(this, $('#results-single').get(0), 'Cases');
       });
       $('#results-export').children('a').eq(1).click(function() {
	  return ExcellentExport.csv(this, $('#results-single').get(0), ",");
        });
       $('#sev-results-export').children('a').first().click(function() {
	  return ExcellentExport.severalExcel(this, document.getElementsByName('todo-kam'), "To do's"); //document.getElementsByName("todo-kam")[0]
        });
    }
    if ($.tablesorter) {
      $('#results:not(.no-sort)').tablesorter();
      $('.sortable').tablesorter();
      $('table.todo').tablesorter({ textExtraction: function(node) {
          var n = node.getElementsByTagName('a');
          if (n.length === 0) {
            n = node.getElementsByTagName('span');
          }
          if (n.length > 0) {
            return n[0].textContent;
          } else {
            return node.textContent;
          }
        }
      });
    }
    $('table.signature').click(handleClick);
  }

  jQuery(function() { init(); });
}());
