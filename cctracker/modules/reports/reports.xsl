<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <!-- pass through => epilogue will do a redirection -->
  <xsl:template match="/Redirected">
    <site:view/>
  </xsl:template>

  <!-- blank page with window title to notify error in flash -->
  <xsl:template match="/error">
    <site:view>
      <site:window><title>Case Tracker reports console</title></site:window>
    </site:view>
  </xsl:template>

  <!-- reports console UI -->
  <xsl:template match="/Reports">
    <site:view>
      <site:window><title>Case Tracker reports console</title></site:window>
      <site:content>
        <div class="row"><div class="span12"><h1>Case Tracker reports console</h1></div></div>
        <xsl:apply-templates select="Menu"/>
        <xsl:apply-templates select="." mode="table"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Menu">
    <form id="ct-report-menu" class="form-horizontal" action="reports/1" method="post">
      <div class="row">
        <div class="span3">
          <label>Lower bound</label>
          <input required="1" type="text" name="min" value="{ @Min }"/>
        </div>
        <div class="span3">
          <label>Upper bound</label>
          <input required="1" type="text" name="max" value="{ @Max }"/>
        </div>
        <div class="span3">
          <label>Freshness</label>
          <input required="1" type="text" name="f" value="{ @Freshness }" readonly="1"/>
        </div>
        <div class="span3">
          <input required="1" type="checkbox" name="c" value="1"/> Reset cache
        </div>
      </div>
      <div style="display:none">
        <input required="1" type="text" name="no" value="1"/>
      </div>
    </form>
  </xsl:template>

  <xsl:template match="Reports" mode="table">
    <table class="table table-bordered">
      <thead>
        <tr>
          <th>No</th>
          <th>Title</th>
          <th>Started</th>
          <th>Duration</th>
          <th style="min-width: 150px">Cache Size (# entries)</th>
          <th>Statistics</th>
          <th>Download</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Report"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Reports[not(Report)]" mode="table">
    <p>No report configured, please see <i>reports.xml</i> in your application configuration</p>
  </xsl:template>

  <xsl:template match="Report">
      <tr>
        <td><xsl:value-of select="No"/><xsl:if test="@Running = '0'"><xsl:text> </xsl:text>(<a class="run" href="javascript:$('a.run').before('&lt;i>wait&lt;/i>').empty();$('#ct-report-menu').attr('action', 'reports/{No}').submit();">run</a>)</xsl:if></td>
        <td><xsl:value-of select="Title"/><xsl:apply-templates select="Note"/></td>
        <td><xsl:value-of select="substring(Start, 1, 10)"/> at <xsl:value-of select="substring(Start, 12, 5)"/></td>
        <td><xsl:apply-templates select="Duration | Errors"/></td>
        <td><xsl:value-of select="CachePivots"/> <span style="font-size:85%">(<xsl:value-of select="TotalPivots"/>)</span> of <xsl:value-of select="CacheSamples"/> <span style="font-size:85%">(<xsl:value-of select="TotalSamples"/>)</span><br/>
        expired: <xsl:value-of select="Dirty"/><br/>
        sealed: <xsl:value-of select="Sealed"/><br/>
        single <xsl:apply-templates select="Orphans"/>: <xsl:value-of select="TotalOrphans"/><br/>
        child: <xsl:value-of select="TotalPivoted"/>
      </td>
        <td>
          replace: <xsl:value-of select="Replace"/><br/>
          insert: <xsl:value-of select="Insert"/><br/>
          delete: <xsl:value-of select="Delete"/><br/>
          hit: <xsl:value-of select="Hit"/>
        </td>
        <td><a href="reports/{No}.xlsx">excel</a></td>
      </tr>
  </xsl:template>

  <xsl:template match="Note"><p style="margin-top: 20px;font-size:0.75em"><xsl:value-of select="."/></p>
  </xsl:template>
  
  <xsl:template match="Orphans">(<xsl:value-of select="."/>)
  </xsl:template>

  <xsl:template match="Duration"><xsl:value-of select="."/> sec
  </xsl:template>

  <xsl:template match="Duration[. = '...']" priority="1"><i>running</i>
  </xsl:template>

  <xsl:template match="Errors"><xsl:if test="../LastRun = 'err'"><br/><br/><i style="color:red">interrupted</i></xsl:if><xsl:apply-templates select="Error"/>
  </xsl:template>
  
  <!-- suspend last run error display if running  -->
  <xsl:template match="Errors[../Duration = '...']" priority="1">
  </xsl:template>

  <xsl:template match="Error"><br/><br/><span style="color:red"><xsl:value-of select="."/></span>
  </xsl:template>

</xsl:stylesheet>
