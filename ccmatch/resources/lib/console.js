(function () {

  var OPEN_IN_NEW_WINDOW = false;

  function loadResponse ( data, status, xhr ) {
    if (status === 'error') {
      $('#output').html(data.responseText);
    } else {
      $('#output').html(xhr.responseText);
    }
  }

  function handleClick (ev) {
    var n = $(ev.target),
        t = n.text(),
        id = $.trim(n.parents('tr').children('td:nth-child(1)').text());
      if (OPEN_IN_NEW_WINDOW && t === 'dump') {
        n.attr('target', 'blank');
        n.attr('href', 'feeds/' + id + '.xml').click();
      } else if ((n.get(0).nodeName.toLowerCase() === 'a') && (!(t.match(/^\d+$/)))) {
        $.ajax({
          url : 'feeds/' + id + '?action=' + t + '&algo=' + $('#c-algo').val(),
          type : 'get',
          async : false,
          dataType : 'xml',
          cache : false,
          timeout : 50000,
          contentType : "application/xml; charset=UTF-8",
          success : loadResponse,
          error : loadResponse
        });
      }
  }

  function addAlgoClick (ev) {
    var n = $(ev.target),
        t = n.text(),
        h = n.attr('href');
    if (t !== 'histories') {
      n.attr('href', h + '&algo=' + $('#c-algo').val()); //.click();
    }
  }

  function init() {
    $('#feeds').click(handleClick)
    $('#c-help').click(addAlgoClick)
  }

  jQuery(function() { init(); });
}());
