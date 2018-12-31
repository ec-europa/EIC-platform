<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/Remotes[not(Remote)]">
    <div id="results">
      <p>Nobody</p>
    </div>
  </xsl:template>

  <xsl:template name="roles-legend">
    <xsl:variable name="gi">
      <xsl:value-of select="concat('xmldb:exist:///db/sites/cctracker/global-information/global-information.xml', '')"/>
    </xsl:variable>
    <table>
      <thead>
        <tr>
          <xsl:for-each select="document($gi)//Function">
            <xsl:if test="Brief != Name">
              <th style="color:#004563"><xsl:value-of select="Brief"/></th>
            </xsl:if>
          </xsl:for-each>
        </tr>
      </thead>
      <tbody>
        <tr>
          <xsl:for-each select="document($gi)//Function">
            <xsl:if test="Brief != Name">
              <td><xsl:value-of select="Name"/></td>
            </xsl:if>
          </xsl:for-each>
        </tr>
      </tbody>
    </table>
  </xsl:template>
  
  <xsl:template match="/Remotes">
    <div id="results">
      <h1>Remote Users pre-registration</h1>
      <p>The database references <b><xsl:value-of select="count(Remote)"/></b> persons who have credentials in an external realm without having a user profile and have <b>not yet</b> accessed to the application.</p>
      <p>This made, s(he) will get a regular user profile that afterwards could be managed from Users tab.</p>
      <p>This tab will allow to prepare their first connection and to create and fill in automatically their profiles from information gathered from the external realm.</p>
      <fieldgroup class="noprint" styme="clear:both">
        <legend>Legend for shortened role name</legend>
        <xsl:call-template name="roles-legend"/>
      </fieldgroup>
      <div style="margin:2em 0 0.5em 0">
        <div style="float:right">
          <button class="btn btn-primary" data-target-modal="c-noremote-editor-modal" data-target="c-noremote-editor" data-edit-action="create" data-src="profiles/add" data-command="add">Add a remote</button>
          <a download="results.xls" href="#" class="btn export">Reset filters</a>
        </div>
        <p class="text-info" style="padding-top:1em">Click on a column header to sort the table</p>
      </div>
      <table name="users" class="table table-bordered todo" style="font-size:8pt">
        <thead>
          <tr>
            <th>Key <span style="font-weight:normal;display:block"><input style="width:170px" id="key-filter"/></span></th>
            <th>Name</th>
            <th>Mail</th>
            <th>Realm</th>
            <th>Roles<span style="font-weight:normal;display:block"><input style="width:50px" id="role-filter"/></span></th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select="Remote"/>
        </tbody>
      </table>
    </div>
  </xsl:template>

  <xsl:template match="Remote">
    <tr class="unstyled">
      <td><span class="fn"><xsl:value-of select="Key"/></span></td>
      <td><xsl:value-of select="Name"/></td>
      <td><xsl:value-of select="Mail"/></td>
      <td><xsl:value-of select="Realm"/></td>
      <td><xsl:apply-templates select="Roles"/></td>
    </tr>
  </xsl:template>

  <xsl:template match="Roles">
    <a><span class="rn" data-remote="profiles?key={../Key}"><xsl:value-of select="."/></span></a>
  </xsl:template>

</xsl:stylesheet>
