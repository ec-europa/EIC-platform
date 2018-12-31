<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach Match suggestion tunnel single page generation

     September 2015 - (c) Copyright may be reserved
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="AjaxFragment">
    <div>
      <xsl:copy-of select="@class"/>
      <xsl:apply-templates select="@Id"/>
      <xsl:value-of select="."/>
    </div>
  </xsl:template>
  
  <xsl:template match="Handout[parent::Suggest-Evaluation]" mode="suggest">
    <button class="btn btn-primary" id="cm-eva-shortlist-button">Add to handout list</button>
  </xsl:template>

  <xsl:template match="Handout[parent::Suggest-Inspect]" mode="suggest">
    <button class="btn btn-primary" id="cm-inspect-shortlist-button">Add to handout list</button>
  </xsl:template>

  <!-- between <span id="cm-{@Target}-competence-min">0</span> % `
       and <span id="cm-{@Target}-competence-max">100</span> % -->
  <xsl:template match="Suggest-Filters">
    <p style="clear:both">Ranking of <span id="cm-{@Target}-competence-number">0</span> coach profiles initially sorted by competence fit (first) and SME Context fit (second). You can sort by clicking on the column headers.</p>
  </xsl:template>

  <xsl:template match="Suggest-Filters[@Target = 'criteria']">
    <p style="clear:both">List of <span id="cm-{@Target}-competence-number">0</span> coach/es who accepted being visible to other coaches on Coach Match</p>
  </xsl:template>

  <!-- Results table for search by fit -->
  <xsl:template match="Suggest-Results">
    <table id="cm-{@Target}-results" class="table table-bordered" data-command="{@Target}-table">
      <xsl:attribute name="data-table-configure">sort filter<xsl:if test="@Services"> <xsl:value-of select="@Services"/></xsl:if></xsl:attribute>
      <xsl:copy-of select="@data-analytics-controller | @data-analytics-uuid"/>
      <thead>
        <tr>
          <th data-sort="Name" data-filter="Name"><span class="head">Name of coaches</span><br/><input type="text" style="max-width:10em"/></th>
          <th data-sort="-Competence" style="min-width: 5em"><span class="head">Competence fit</span><span class="sg-hint" rel="tooltip" title-loc="fit.competence.hint">?</span></th>
          <th data-sort="-Context" style="min-width: 5em"><span class="head">SME context fit</span><span class="sg-hint" rel="tooltip" title-loc="fit.context.hint">?</span></th>
          <th data-sort="-Perf" style="min-width: 5em"><span class="head">SME rating</span><span class="sg-hint" rel="tooltip" title-loc="sme.rating.hint">?</span></th>
          <th data-filter="Languages"><span class="head">Languages</span><br/><input type="text" style="max-width:100px"/></th>
          <th data-sort="Country" data-filter="Country"><span class="head">Country of residence</span><br/><input type="text" style="max-width:90px"/></th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>
  
  <!-- Results table for search by criteria -->
  <xsl:template match="Suggest-Results[@Target = 'criteria']">
    <table id="cm-{@Target}-results" class="table table-bordered" data-command="{@Target}-table">
      <xsl:attribute name="data-table-configure">sort filter<xsl:if test="@Services"> <xsl:value-of select="@Services"/></xsl:if></xsl:attribute>
      <xsl:copy-of select="@data-analytics-controller"/>
      <thead>
        <tr>
          <th data-sort="Name" data-filter="Name"><span class="head">Name of coaches</span><br/><input type="text" style="max-width:10em"/></th>
          <th data-filter="Languages"><span class="head">Languages</span><br/><input type="text" style="max-width:100px"/></th>
          <th data-sort="Country" data-filter="Country"><span class="head">Country of residence</span><br/><input type="text" style="max-width:90px"/></th>
          <th data-sort="-Perf"><span class="head">SME rating</span><span class="sg-hint" rel="tooltip" title-loc="sme.rating.hint">?</span></th>
          <th>Keywords in context</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Suggest-ShortList">
    <h2>Handout list</h2>
    <table id="cm-shortlist" class="table table-bordered" data-command="shortlist-table">
      <thead>
        <tr>
          <th style="min-width:12em">Name of coaches</th>
          <th style="min-width:5em">Competence fit<span class="sg-hint" rel="tooltip" title-loc="fit.competence.hint">?</span></th>
          <th style="min-width:5em">SME context fit<span class="sg-hint" rel="tooltip" title-loc="fit.context.hint">?</span></th>
          <th style="min-width:5em">SME rating<span class="sg-hint" rel="tooltip" title-loc="sme.rating.hint">?</span></th>
          <th>Languages</th>
          <th>Country of residence</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
    <button class="btn btn-primary" id="cm-shortlist-handout-button"><xsl:copy-of select="@data-analytics-uuid"/>Show Handout for printing</button>
  </xsl:template>

  <!-- TODO: <Commands> for menu placement (?) -->
  <xsl:template match="Suggest-Evaluation">
    <div class="row-fluid noprint" style="margin: 10px 0">
      <div class="span12">
        <button class="btn btn-primary" data-command="back-to-search" data-overlay="evaluation">Back to coach search</button>
      </div>
    </div>
    <h2>Executive summary for <span id="cm-eva-name-var"></span></h2>
    <p id="cm-eva-summary"/>
    <xsl:apply-templates select="*[local-name() != 'Handout']"/>
    <div class="row-fluid noprint" style="margin-bottom: 20px">
      <div class="span6">
        <button class="btn btn-primary" data-command="back-to-search" data-overlay="evaluation">Back to coach search</button>
        <xsl:apply-templates select="Handout" mode="suggest"/>
      </div>
      <div class="span6">
        <a class="btn btn-primary" id="cm-evaluation-cv-button" target="_blank" style="float:right"><xsl:copy-of select="@data-analytics-controller"/>Curriculum Vitae (online)</a>
        <a class="btn btn-primary" id="cm-evaluation-pdf-button" target="_blank" style="float:right;margin-right:5px"><xsl:copy-of select="@data-analytics-controller"/>Curriculum Vitae (PDF)</a>
      </div>
    </div>
  </xsl:template>

  <!-- HTML template with title with fit score, summary and details tables
       to visualize coach JSON evaluation data for a given dimension

      <table id="cm-eva-{@Key}-summary" class="table table-bordered">
        <thead>
          <tr>
            <th>Performance indicators</th>
            <th>Performance values</th>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    -->
  <xsl:template match="Suggest-Dimension">
    <div id="cm-eva-{@Key}-view" class="cm-eva-dim row-fluid">
      <h3><xsl:value-of select="@Title"/> fit <span id="cm-eva-{@Key}-var"></span></h3>
      <div id="cm-eva-{@Key}-summary" class="cm-radar"/>
      <h4><xsl:value-of select="@Title"/> fit details</h4>
      <table id="cm-eva-{@Key}-details" class="table table-bordered">
        <thead>
          <tr>
             <th rowspan="2">Business innovation system</th>
             <th colspan="3">Coach competences with regards to the <xsl:value-of select="."/></th>
          </tr>
          <tr>
            <th>Weaknesses</th>
            <th>Medium</th>
            <th>Strenghts</th>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    </div>
  </xsl:template>

  <!-- Parameterized cm-handout-content ? 
       Note buttons are replicated inside handhout.xsl (top right)
        -->
  <xsl:template match="Suggest-Handout">
    <p id="cm-handout-busy" class="cm-busy">Loading handout</p>
    <div id="cm-handout-content"/>
    <div class="noprint" style="clear:left">
      <button class="btn btn-primary" onclick="javascript:window.print();">Print</button>
      <button id="back-in-handout" class="btn btn-primary" data-command="back-to-search" data-overlay="handout">Back to coach search</button>
    </div>
  </xsl:template>
  
  <xsl:template match="Suggest-Inspect">
    <p id="cm-inspect-busy" class="cm-busy">Loading profile</p>
    <div class="row-fluid noprint" style="margin: 10px 0">
      <div class="span12">
        <button class="btn btn-primary" data-command="back-to-search" data-overlay="inspect">Back to coach search</button>
      </div>
    </div>
    <div id="cm-inspect-content">
      <p>This page will show the details of the coach competences and experiences in the future</p>
    </div>
    <div class="row-fluid noprint" style="margin-bottom: 20px">
      <div class="span6">
        <button class="btn btn-primary" data-command="back-to-search" data-overlay="inspect">Back to coach search</button>
        <xsl:apply-templates select="Handout" mode="suggest"/>
      </div>
      <div class="span6">
        <a class="btn btn-primary" id="cm-inspect-cv-button" target="_blank" style="float:right">Curriculum Vitae (online)</a>
        <a class="btn btn-primary" id="cm-inspect-pdf-button" target="_blank" style="float:right;margin-right:5px">Curriculum Vitae (PDF)</a>
      </div>
    </div>
  </xsl:template>

</xsl:stylesheet>
