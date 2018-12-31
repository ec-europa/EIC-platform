<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/search.xsl"/>

  <!-- summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Import-Summary">
    <p id="{.}-summary" class="xcm-search-summary">Imported <span class="xcm-counter">0</span> <span class="xcm-plural">companies</span><span class="xcm-singular">company</span></p>
  </xsl:template>

  <!-- table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Import-ResultsTable">
    <table id="{.}-results" class="ecl-table ecl-table-responsive xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Outcome"><span class="head">Outcome</span></th>
          <th>Notes</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

  <!-- TODO: move to commons.xsl ? -->
  <xsl:template match="error" priority="1">
    <h2>Oops !</h2>
  </xsl:template>
</xsl:stylesheet>
