/*****************************************************************************\
|                                                                             |
|  'stats' command                                                            |
|                                                                             |
|  Implements micro-format instructions generated from stats.xml to query     |
|  and plot a data set using d3.js                                            |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS, d3.js, ExcellentExport            |
|                                                                             |
\*****************************************************************************/
(function ($axel) {

  var DB;
  var DONE = 0;
  var DEFAULTS = {
    'width' : 800
  }
  var WHEEL;

  function formatDate (s) {
    if (s) {
      return s.substr(8,2) + '/' +  s.substr(5,2) + '/' +  s.substr(0,4);
    } else {
      return 'null'
    }
  }

  // Decodes value to a string label using matching DB.Variables entry for varname
  // Manages single value domains (string) or multi values domain (array)
  function decodeLabel ( varname, value ) {
    var convert = DB.Variables[varname], trans, pos, output, res = "";
    if (convert) {
      trans = $.isArray(convert.Values) ? convert.Values : [ convert.Values ] || convert,
      pos = trans.indexOf(value),
      output = $.isArray(convert.Labels) ? convert.Labels : [ convert.Labels ] || convert;
      res = output[pos] || value;
    }
    return res;
  }

  function meanRowStrict( row, ranks ) {
    var i, res = 0, prev, count = 0;
    for (i = 0; i < ranks.length; i++) {
      prev = res;
      res += row[ranks[i] - 1];
      if (prev != res) {
        count++;
      }
    }
    return (res > 0) && (count === ranks.length) ? res / ranks.length : 0; // strict
  }

  function meanRowLiberal( row, ranks ) {
    var i, res = 0, prev, count = 0;
    for (i = 0; i < ranks.length; i++) {
      prev = res;
      res += row[ranks[i] - 1];
      if (prev != res) {
        count++;
      }
    }
    return (res > 0) && (count > 0) ? res / count : 0; // liberal
  }

  // Implements Composition variable which is a set of dimensions, each dimension
  // is computed as the mean of different indexical values of the composed variable 
  // of the data set which must contain an array
  // data-composition is the name of the variabel from the data set to compose 
  // 
  function calcMeanComposition ( config, name, values, tuples ) {
      var res = { mean : new Array(values.length),
                  count : new Array(values.length)
                },
          ranks = new Array(values.length),
                dim, i, j, row, pos, prev, mmranks,
                buff = new Array(values.length);
      for (i = 0; i < values.length; i++) {
        res.mean[i] = res.count[i] = buff[i] = 0;
        dim = 'dimension' + values[i].charAt(0) + values[i].substr(1).toLowerCase();
        ranks[i] = $.trim(config[dim]).split(' ');
        window.console.log(values[i] + ' computed from ' + config.composition + ' at ' + ranks[i].join('/'));
      }
      // prepares means of means ranks index
      mmranks = []; 
      for (i = 0; i < values.length; i++) {
        if (ranks[i][0] !== '-1') {
          mmranks.push(i + 1);
        }
      }
      // window.console.log('means of means vector of ' + dim + ' is ' + mmranks);
      // computes means for each dimension
      for (i = 0; i < tuples.length; i++) {
        row = tuples[i][config.composition];
        for (j = 0; j < values.length; j++) {
          prev = res.mean[j];
          if (ranks[j][0] === '-1') { // special means of means dimension
            res.mean[j] += meanRowStrict(buff, mmranks);
            window.console.log('strict of ' + buff + ' is ' + meanRowStrict(buff, mmranks));
            // FIXME: actually only works if latest dimension !
          } else {
            buff[j] = meanRowLiberal(row, ranks[j]);
            res.mean[j] += buff[j];
          }
          if (prev !== res.mean[j]) {
            res.count[j] += 1;
          }
        }
      }
      for (i = 0; i < values.length; i++) {
        res.mean[i] = res.mean[i] > 0 ? Math.round((6 - res.mean[i] / res.count[i]) * 100) / 100 : res.mean[i];
        //window.console.log(values[i] + ' = ' + res.mean[i]);
      }
      return res;
  }

  // Returns frequency diagram for name variable in tuples in domain 
  // Manages single value domain (string) or multi values domain (array)
  function calcVarDistribution ( name, domain, tuples ) {
      var values = typeof domain === 'string' ? [ domain ] : domain,
          res = new Array(values.length), i, pos;
      for (i = 0; i < values.length; i++) {
          res[i] = 0;
      }
      for (i = 0; i < tuples.length; i++) {
        pos = values.indexOf(tuples[i][name]);
       if (pos != -1) {
           res[pos]++;
       }
      }
      return { frequency : res };
  }

  // TODO: specific calcVectorLiteralDistribution ?
  function calcVectorDistribution ( nameFunc, values, tuples ) {
      var res = { frequency : new Array(values.length) },
          sum = new Array(values.length),
          bi = false,
          i, j, row, pos;
      for (i = 0; i < values.length; i++) {
        res.frequency[i] = sum[i] = 0;
      }
      for (i = 0; i < tuples.length; i++) {
        row = nameFunc(tuples[i]);
        if (typeof row === "number") { /* integer singleton */
          pos = values.indexOf(row);
          res.frequency[pos]++;
        } else if (typeof row === "string") { /* integer singleton */
          pos = values.indexOf(row);
          if (pos != -1) {
               res.frequency[pos]++;
          }
        } else if ($.isArray(row)) { /* assumes array of string or array of { Id: Value: } hash pairs */
          for (j = 0; j < row.length; j++) {
            if (typeof row[j] === "string") {
              pos = values.indexOf(row[j]);
              if (pos != -1) {
                   res.frequency[pos]++;
               }
            } else { /* assumes { Id: Value: } hash pair */
              pos = values.indexOf(row[j].Id);
              if (pos != -1) {
                   res.frequency[pos]++;
                   sum[pos] += row[j].Value;
                   bi = true;
              }
            }
          }
        } else if (row) { /* assumes { Id: Value: } hash pair */
          pos = values.indexOf(row.Id);
          if (pos != -1) {
               res.frequency[pos]++;
               sum[pos] += row.Value;
               bi = true;
           }
        }
      }
      if (bi) {
        res.sum = sum;
      }
      return res;
  }

  // Genrates plain tables (no colspan, rowspan) using d3
  function genTable( div, config ) {
    var rows, cells;

    // table rows maintenance
    rows = div.select('table tbody').selectAll('tr').data(config.data);
    rows.enter().append('tr');
    rows.exit().remove();

    // cells maintenance
    cells = div.select('table tbody').selectAll('tr').selectAll('td').data(function(d) { return d; });
    cells.text(function(d) { return d; }); // update
    cells.enter().append('td').text(function(d) { return d; }); // create
    cells.exit().remove(); // delete
  }

  // TODO : supporter update et remove
  function genD3Chart( div, chart, config ) {
    var margin = {top: config.top, right: config.right, bottom: config.bottom, left: config.left},
        width = config.width - margin.left - margin.right,
        height = config.height - margin.top - margin.bottom,
        angle = config.angle,
        s = config.data.length,
        padding, x, y, chart;

    if (s >= 10) {
      padding = 0.1;
    } else if (s <= 5) {
      padding = 0.6;
    } else {
      padding = (11 - s) / 10;
    }

    y = d3.scale.linear()
          .range([height, 0]);
    x = d3.scale.ordinal()
          .rangeRoundBands([0, width], padding);
    chart = div.select("svg");

    if (config.update === "destructive") { // destroy graph and rebuild it
      chart.select("g").remove();
    }

    if (chart.select("g").size() === 0) { // fixed once from page HTML microformat not transmitted through JSON
      chart.attr("width", width + margin.left + margin.right)
           .attr("height", height + margin.top + margin.bottom)
           .append("g")
           .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
    }

    var xAxis = d3.svg.axis()
        .scale(x)
        .orient("bottom");

    if (config.size) { // limits ticks size in characters
      xAxis.tickFormat(function(d) { return d.substring(0, config.size -1) + " ..."; });
    }

    x.domain(config.data.map(function(d) { return d[0]; }));
    y.domain([0, d3.max(config.data, function(d) { return d[1]; })]);

    var barWidth = width / config.data.length;

    var bar = chart.select("g").selectAll("g").data(config.data);

    // create
    bar = bar.enter().append("g").attr("class", "bar");
    bar.append("rect");
    bar.append("text");

    // update
    bar = chart.select("g").selectAll("g.bar");
    bar.attr("transform", function(d) { return "translate(" + x(d[0]) + ",0)"; })
      .select("rect")
      .attr("y", function(d) { return y(d[1]); })
      .attr("height", function(d) { return height - y(d[1]); })
      .attr("width", x.rangeBand());

    bar.select("text")
      .attr("x", x.rangeBand() / 2)
      .attr("y", function(d) { return y(d[1]) + 3; })
      .attr("dy", ".75em")
      .text(function(d) { return d[1]; });

    if (chart.select("g").select("g.x.d3axis").size() === 0) {
      var legend = chart.select("g").append("g")
          .attr("class", "x d3axis")
          .attr("transform", "translate(0," + height + ")")
          .call(xAxis)
          .selectAll("text")
          .style("text-anchor", angle === 0 ? "middle" : "end")
          .attr("dy", "0.75em");

      if (angle >= 60) {
        legend.attr("transform", "translate(-15, 10) rotate(-" + angle + ")");
      } else if (angle !== 0) {
        legend.attr("transform", "rotate(-" + angle + ")");
      }
    }
  }

  // implements Chart element from stats.xml using C3 and pre-gen config
  // complete to add/interface other graph types
  function genC3Chart( config, chart, values, distrib ) {
    var c3data,
        varname = config.variable,
        _order = chart && chart.Configuration ? chart.Configuration.Order : null,
        _type = chart && chart.Configuration ? chart.Configuration.Type : 'bar';
    if (_type === 'pie') {
      c3data = d3.zip(values, distrib.frequency);
    } else  {
      // bar chart
      c3data = Array.from(distrib.frequency);
      c3data.splice(0, 0, 'Number of coaches');
      c3data = [ c3data ];
    }
    c3.generate({
        bindto: '#chart-' + varname,
        data: {
          columns:
            c3data,
          type : _type,
          order: _order || 'asc'
        },
        axis : {
          x : {
            type: 'category',
            categories : values
          }
        }
    });
  }

  // FIXME: check all distribs are [[n1, x1], [n2, x2], etc. ]
  function preSort(distrib) {
    return distrib.sort((function(a,b) { return d3.ascending(a[1],b[1])}));
  }

  // Generates tables and graphs (to be called for each div.chart)
  // DEPRECATED: use C3 and direct JSON graph configuration (less micro-format)
  function d3Generation ( selection ) {
    selection.each(function (d, i) {
      var varname = d.variable, // variable plot + table
          cur,
          values, distrib, percents, matrix, c3data, chart,
          div = d3.select(this),
          table,
          legends;

      if (varname) {
        // table matrix creation
        if (DB.Variables[varname]) {
          // handles single values domains (string) or multi values domains (array)
          values = DB.Variables[varname].Labels || DB.Variables[varname];
          if (typeof values === 'string') {
            values = [ values ];
          }
          if (d.type === 'vector') {
            if (d.rank) {
              cur = parseInt(d.rank) - 1;
              distrib = calcVectorDistribution(function(sample) { return sample[varname][cur]; }, 
              DB.Variables[varname].Values || DB.Variables[varname], DB[d.set]);
            } else {
              distrib = calcVectorDistribution(function(sample) { return sample[varname]; }, 
              DB.Variables[varname].Values || DB.Variables[varname], DB[d.set]);
            }
          } else if (d.type === 'composition') {
            // FIXME: these conversions could be done server-side (JSON serializer) ?
            if (typeof DB.Variables[varname].Values === "string")  {
              DB.Variables[varname].Values = [ DB.Variables[varname].Values ]
            }
            if (typeof DB.Variables[varname].Legends === "string")  {
              DB.Variables[varname].Legends = [ DB.Variables[varname].Legends ]
            }
            if (typeof DB.Variables[varname].Labels === "string")  {
              DB.Variables[varname].Labels = [ DB.Variables[varname].Labels ]
            }
            distrib = calcMeanComposition(d, varname, DB.Variables[varname].Values || DB.Variables[varname], DB[d.set]); 
          } else { 
            distrib = calcVarDistribution(varname, DB.Variables[varname].Values || DB.Variables[varname], DB[d.set]); 
          }
          // retrieves Chart specification
          chart= DB.Charts.filter( 
            function( e ) { 
              var t;
              if (e.Variable) {
                t = e.Variable['#text'];
              } else if (e.Vector) {
                t = e.Vector['#text'];
              }
              return t === varname;
            } 
          );
          chart = chart.length > 0 ? chart[0] : null;
          if (chart && chart.Configuration && chart.Configuration.Format === 'compact') {
            // only meaningful for frequency distributions (aka a Variable or Vector chart) - no mean
            values = values.filter(function (e, i) { return distrib.frequency[i] !== 0 });
            distrib.frequency = distrib.frequency.filter(function (e, i) { return distrib.frequency[i] !== 0 });
            if (distrib.sum) {
              distrib.sum = distrib.sum.filter(function (e, i) { return distrib.sum[i] !== 0 });
            }
          }
          if (distrib.sum) {
            percents =  distrib.sum.map( function( val ) { return this == 0 ? '-' : Math.round(val / this * 100) + '%'; }, d3.sum(distrib.sum));
            matrix = d3.zip(values, distrib.frequency, distrib.sum, percents);
            matrix.push(['Total', d3.sum(distrib.frequency), d3.sum(distrib.sum), '100%']);
          } else if (distrib.mean) {
            matrix = d3.zip(values, distrib.mean, distrib.count);
          } else {
            percents =  distrib.frequency.map( function( val ) { return this == 0 ? '-' : Math.round(val / this * 100) + '%'; }, d3.sum(distrib.frequency));
            matrix = d3.zip(values, distrib.frequency, percents);
            matrix.push(['Total', d3.sum(distrib.frequency), '100%']);
          }
        } else {
          return;
        }
        // graph creation
        legends = (d.type === 'composition') ? DB.Variables[varname].Legends : values;
        if (d.library === 'C3') {
          genC3Chart(d, chart, values, distrib);
        } else {
          // FIXME: implement Configuration.Order (preSort, etc.)
          div.selectAll('svg').data([d]).enter().insert('svg:svg','table');
          genD3Chart( div, chart,
            {
            top : +(d.top || 20),
            width : +(d.width || DEFAULTS.width),
            height : +(d.height || 400),
            bottom : +(d.bottom || 20),
            angle : +(d.angle || 0),
            left : +(d.left || 0),
            right : +(d.right || 0),
            size : +(d.size || 0),
            update : d.update || "destructive", // destructive by default because next line always sorts
            data : preSort(d3.zip(legends, distrib.sum || distrib.frequency || distrib.mean))
            });
        }
      }

      // table creation (bootstrapped from XSLT for l14n purpose)
      // table = div.selectAll('table').data([d]).enter().append('table').classed({'stats' : true}).style({ "margin-top" : "20px", "margin-bottom" : "30px"});
      // table.append('thead').append('tr').selectAll('th').data(columns).enter().append('th').text( function(d) { return d } );
      // table.append('tbody');
      genTable (div, { data : matrix });
      });
  }

  function submitStatsSuccess ( data, status, xhr, memo ) {
    DB = {
          Coaches : (data.Coaches === undefined || $.isArray(data.Coaches)) ? data.Coaches : [ data.Coaches ],
          Variables : data.Variables,
          Charts : data.Charts ? data.Charts.Chart : []
         };
    this.spec.removeAttr('disabled');
    $(WHEEL).hide();
    if (DB.Coaches) { // something to plot
      $('#no-sample').hide();
      $('#with-sample').show();
      if (DB.Coaches) {
        $('#dataset-nb').next('span').show().prev().text(DB.Coaches.length).show().parent();
      } else {
        $('#dataset-nb').hide().next('span').hide();
      }
      try {
        d3.selectAll('div.chart').datum(
          function(d, i) {
            var item = d3.select(this).node().dataset; // converts microformat to d3 datum
            return item;
          }
        ).style('display', 'block').call(d3Generation);
        if (! DONE) { // install export
          $('table.stats').each(function() {
             var table = $(this).get(0),
                 $links = $(this).next('div.export').children('a'),
                 excel, csv;
             excel = $links.get(0);
             $(excel).click(function() {
               return ExcellentExport.excel(this, table, 'Sheet Name Here');
             });
             csv = $links.get(1);
             $(csv).click(function() {
               return ExcellentExport.csv(this, table, ";");
             });
            });
          DONE = 1;
        }
      } catch (e) {
        alert('Exception [' + e.name + ' / ' + e.message + '] thanks to send this message to a developer !');
      }
    } else { // nothing to plot
      $('#no-sample').show();
      $('#with-sample').hide();
      d3.selectAll('div.chart').style('display', 'none');
    }
  }

  function submitStatsError ( xhr, status, e )  {
    this.spec.removeAttr('disabled');
    $(WHEEL).hide();
    $('body').trigger('axel-network-error', { xhr : xhr, status : status, e : e });
  }

  function StatsCommand ( identifier, node ) {
    this.spec = $(node);
    this.spec.click($.proxy(this, 'execute'));
    WHEEL = '#' + this.spec.attr('data-spinning-wheel');
    // overwrites default global parameters
    DEFAULTS.width = this.spec.attr('data-width')|| DEFAULTS.width;
    // TODO: extra optional sub-commands to be sorted out !!!
    $('#filter-export').children('a').first().click(function() {
       return ExcellentExport.excel(this, $('#editor table').get(0), 'Criteria');
     });
    $('#filter-export').children('a').eq(1).click(function() {
       return ExcellentExport.csv(this, $('#editor table').get(0), ",");
      });
    $('#results-export').children('a').first().click(function() {
      return ExcellentExport.doubleExcel(this, $('#filters').get(0), $('#results').get(0), 'Résultats');
    });
    $('#results-export').children('a').eq(1).click(function() {
      return ExcellentExport.csv(this, $('#results').get(0), ",");
    });
    if ($.tablesorter) {
      $('body#export #results').tablesorter();
    }    
  }

  StatsCommand.prototype = {
    execute : function (ev) {
      this.spec.attr('disabled', true);
      $(WHEEL).show();
      $.ajax({
        url : this.spec.attr('data-src'),
        type : 'post',
        async : false,
        data : $axel('#editor').xml(),
        dataType : 'json',
        cache : false,
        timeout : 50000,
        contentType : "application/xml; charset=UTF-8",
        success : $.proxy(submitStatsSuccess, this),
        error : $.proxy(submitStatsError, this)
      });
    },
    
  };  
  
  // table export page
  function init() {
    $('#results-export').children('a').first().click(function() {
       return ExcellentExport.doubleExcel(this, $('#filters').get(0), $('#results').get(0), 'Results');
     });
     $('#results-export').children('a').eq(1).click(function() {
      return ExcellentExport.csv(this, $('#results').get(0), ",");
    });
    if ($.tablesorter) {
      $('body#export #results').tablesorter();
    }
  }
  
  if ($axel) { // statistics rendering page
    $axel.command.register('stats', StatsCommand, { check : false });
  } else {
    jQuery(function() { init(); });
  }
}(typeof $axel !== 'undefined' ? $axel : null));
