<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/search.xsl"/>

  <!-- summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Search-Summary">
    <p id="{.}-summary" class="ecl-hading ecl-heading--h4 xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural" style="display:inline">companies</span><span class="xcm-singular" style="display:inline">company</span></p>
  </xsl:template>

  <!-- table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Search-ResultsTable">
    <table id="{.}-results" class="ecl-table ecl-table-responsive xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Town"><span class="head">City</span></th>
          <th data-sort="Country"><span class="head">Country</span></th>
          <th data-sort="Size"><span class="head">Size</span></th>
          <th data-sort="Nace"><span class="head">Nace</span></th>
          <th data-sort="Markets"><span class="head">Markets</span></th>
          <th>Team</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

<!-- FIXME: to be integrated in summary widget ?
  <xsl:template match="@Duration">
    <p style="float:right; color: #004563;">(requête traitée en <xsl:value-of select="."/> s)</p>
  </xsl:template> -->
</xsl:stylesheet>
