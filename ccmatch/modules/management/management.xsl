<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach Match management rendering

     September 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="Management-UserResults">
    <table id="cm-user-results" class="table table-bordered" data-command="user-table" data-table-configure="sort">
      <thead>
        <tr>
          <th data-sort="Name"><span class="head">Name</span></th>
          <th data-sort="Login"><span class="head">Login</span></th>
          <th>Access</th>
          <th>Admin</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
  </xsl:template>
  
  <xsl:template match="Management-ImportResults">
    <table id="cm-import-results" class="table table-bordered" data-command="import-table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Coach Match</th>
          <th>Coach Match Login</th>
          <th>Access</th>
          <th>Case Tracker Login</th>
          <th>Email</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
    
  </xsl:template>

</xsl:stylesheet>
