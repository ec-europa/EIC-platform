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
    <p id="{.}-summary" class="ecl-heading ecl-heading--h4 xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural" style="display:inline">company members</span><span class="xcm-singular" style="display:inline">company member</span></p>
  </xsl:template>

  <!-- table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Search-ResultsTable">
    <table id="{.}-results" class="ecl-table ecl-table-responsive xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Key"><span class="head">EU Login e-mail</span></th>
          <th data-sort="Company"><span class="head">Company</span></th>
          <th data-sort="PO"><span class="head">Project Officer</span></th>
          <th data-sort="CreatedBy"><span class="head">Created By</span></th>
          <th data-sort="Role"><span class="head">Role</span></th>
          <th><span class="head">Access</span></th>
          <th><span class="head">Action</span></th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

  <!-- DEPRECATED - summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Search-Investors-Summary">
    <p id="{.}-summary" class="ecl-heading ecl-heading--h4 xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural" style="display:inline"> investors</span><span class="xcm-singular" style="display:inline">investor</span></p>
  </xsl:template>

  <!-- DEPRECATED - table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Search-Investors-ResultsTable">
    <table id="{.}-results" class="ecl-table ecl-table-responsive xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Key"><span class="head">EU Login e-mail</span></th>
          <th data-sort="Company"><span class="head">Company</span></th>
          <th data-sort="CreatedBy"><span class="head">Created By</span></th>
          <th data-sort="Role"><span class="head">Role</span></th>
          <th><span class="head">Access</span></th>
          <th><span class="head">Admission</span></th>
          <th><span class="head">Action</span></th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

  <!-- summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Search-Entries-Summary">
    <p id="{.}-summary" class="ecl-heading ecl-heading--h4 xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural" style="display:inline"> users</span><span class="xcm-singular" style="display:inline">user</span></p>
  </xsl:template>
  
  <!-- table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Search-Entries-ResultsTable">
    <table id="{.}-results" class="ecl-table ecl-table-responsive xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="CreatedBy"><span class="head">Created By</span></th>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Key"><span class="head">Email</span></th>
          <th data-sort="Company"><span class="head">Organisation name</span></th>         
          <th data-sort="OrganisationTypes"><span class="head">Organisation type</span></th>
          <th data-sort="OrganisationStatus"><span class="head">Organisation status</span></th>
          <th data-sort="Date"><span class="head">Date</span></th>
          <th data-sort="Admission"><span class="head">Admission status</span></th>
          <th><span class="head">User access rights</span></th>
          <th><span class="head">Action</span></th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>
  

  <!-- summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Search-Tokens-Summary">
    <p id="{.}-summary" class="ecl-heading ecl-heading--h4 xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural" style="display:inline">token requests or members</span><span class="xcm-singular" style="display:inline">token request or member</span></p>
  </xsl:template>

  <!-- table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Search-Tokens-ResultsTable">
    <table id="{.}-results" class="table table-bordered xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th><span class="head">Current token owner</span></th>
          <th data-sort="Key"><span class="head">ScaleupEU e-mail</span></th>
          <th><span class="head">EU Login</span></th>
          <th data-sort="Company"><span class="head">Company</span></th>
          <th data-sort="PO"><span class="head">Project Officer</span></th>
          <th data-sort="CreatedBy"><span class="head">Created By</span></th>
          <th data-sort="Role"><span class="head">Role</span></th>
          <th><span class="head">Token Status</span></th>
          <th><span class="head">Action</span></th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

  <!-- summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Search-Unaffiliated-Summary">
    <p id="{.}-summary" class="xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural">unaffiliated users</span><span class="xcm-singular">unaffiliated user</span></p>
  </xsl:template>

  <!-- table widget for '{.}-table' command (see commons.js and search.js) -->
  <xsl:template match="Search-Unaffiliated-ResultsTable">
    <table id="{.}-results" class="table table-bordered xcm-search-results" data-command="{.}-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Key"><span class="head">EU Login e-mail</span></th>
          <th data-sort="CreatedBy"><span class="head">Created By</span></th>
          <th data-sort="Role"><span class="head">Role</span></th>
          <th><span class="head">Access</span></th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>

  <!-- summary widget for 'table' command) (see commons.js) -->
  <xsl:template match="Import-Summary">
    <p id="{.}-summary" class="ecl-heading ecl-heading--h4 xcm-search-summary">Found <span class="xcm-counter">0</span> <span class="xcm-plural" style="display:inline">project officers</span><span class="xcm-singular" style="display:inline">project officer</span></p>
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

<!-- FIXME: to be integrated in summary widget ?
  <xsl:template match="@Duration">
    <p style="float:right; color: #004563;">(requête traitée en <xsl:value-of select="."/> s)</p>
  </xsl:template> -->
</xsl:stylesheet>
