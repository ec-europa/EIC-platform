<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach Match acceptance rendering

     TODO: change name to home.xsl

     June 2016 - (c) Copyright may be reserved
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:template match="Acceptances">
    <table class="table table-bordered">
      <tr>
        <th width="40%">List of coach host organisations using the CoachMatch platform</th>
        <th width="25%">Request acceptances</th>
        <th width="35%">Request Status</th>
      </tr>
      <xsl:apply-templates select="Host"/>
     </table>
  </xsl:template>

  <!-- Renders Host row when not accepted
       Initial idea was to use data-src="#cm-host{@For}-data" with data-island -->
  <xsl:template match="Host">
    <tr>
      <td><xsl:value-of select="Name/text()"/></td>
      <td>
        <button data-target="_n_a" data-command="submit-once" data-verb="Apply"  data-controller="{../@UID}/hosts/{@For}/apply" data-replace-target="cm-host{@For}-status" class="btn btn-primary">Submit application</button>
      </td>
      <td><p id="cm-host{@For}-status">N/A</p></td>
    </tr>
  </xsl:template>

  <!-- Renders Host row when accepted-->
  <xsl:template match="Host[AccreditationRef]">
    <tr>
      <td><xsl:value-of select="Name/text()"/></td>
      <td>
        <button disabled="disabled" class="btn btn-primary">Submit application</button>
      </td>
      <td>
        <p><xsl:value-of select="Status"/></p>
      </td>
    </tr>
  </xsl:template>

  <!-- FIXME: table must be aligned with feeds.xml - could be generated ? -->
  <xsl:template match="Performance-Table">
    <h3>Detail list of performance indicators</h3>
    <table class="table table-bordered">
      <thead>
        <tr>
          <td></td>
          <td>Average rating<br/><span style="font-size:11px">(min: 1, max: 5)</span></td>
          <td>Number of evaluations</td>
        </tr>
      </thead>
      <tbody>
        <tr><td><b>Resource impact</b><span class="sg-hint" rel="tooltip" title-loc="RI.hint">?</span></td><td><b id="RI-avg"/></td><td><b id="RI-nb"/></td></tr>
        <tr><td loc="stats.q8">q8</td><td id="q8-avg"/><td id="q8-nb"/></tr>
        <tr><td loc="stats.q9">q9</td><td id="q9-avg"/><td id="q9-nb"/></tr>
        <tr><td loc="stats.q10">q10</td><td id="q10-avg"/><td id="q10-nb"/></tr>
        <tr><td loc="stats.q11">q11</td><td id="q11-avg"/><td id="q11-nb"/></tr>
        <tr><td loc="stats.q12">q12</td><td id="q12-avg"/><td id="q12-nb"/></tr>
        <tr><td><b>Business impact</b><span class="sg-hint" rel="tooltip" title-loc="BI.hint">?</span></td><td><b id="BI-avg"/></td><td><b id="BI-nb"/></td></tr>
        <tr><td loc="stats.q13">q11</td><td id="q13-avg"/><td id="q13-nb"/></tr>
        <tr><td loc="stats.q14">q12</td><td id="q14-avg"/><td id="q14-nb"/></tr>
        <tr><td><b>SME rating</b></td><td><b id="SME-avg"/></td><td><b id="SME-nb"/></td></tr>
        <tr><td colspan="3"><i loc="stats.sme">sme rating</i></td></tr>
        <tr><td><b>Interaction with KAM</b><span class="sg-hint" rel="tooltip" title-loc="I.hint">?</span></td><td><b id="I-avg"/></td><td><b id="I-nb"/></td></tr>
        <tr><td loc="stats.q15">q15</td><td id="q15-avg"/><td id="q15-nb"/></tr>
      </tbody>
    </table>
  </xsl:template>

  <!-- NOTE:
       Embeds XML data for Ajax submission : in XHTML pages we should output CDATA section
       Not supported at the moment http://exist-open.markmail.org/thread/mb3s7rd4gpojib3f
    -->
  <!-- <xsl:template match="Host" mode="data-island">
    <script id="cm-host{@For}-data" type="text/plain" style="display:none">
      <Host For="{@For}">
        <AccreditationRef>1</AccreditationRef>
      </Host>
    </script>
  </xsl:template> -->
</xsl:stylesheet>
