<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/Persons[not(Person)]">
    <div id="results">
      <p>Nobody</p>
    </div>
  </xsl:template>

  <xsl:template match="/Persons">
    <div id="results">
      <h1>Users management</h1>
      <p>The database references <b><xsl:value-of select="count(Person)"/></b> community member(s).</p>
      <div style="margin:2em 0 0.5em 0">
        <div id="results-export" style="float:right;margin-bottom:10px">
          <!-- temporarily desactivated
          <button class="btn btn-primary" data-target-modal="c-item-editor-modal" data-target="c-item-editor" data-edit-action="create" data-src="persons/add.xml?from=item" data-command="add">Add a person</button>-->
          <a download="accounts-{@Date}.xls" href="#" class="btn btn-primary btn-small export">Generate Excel</a>
          <a download="accounts-{@Date}.csv" href="#" class="btn btn-primary btn-small export">Generate CSV</a>
          <a download="results.xls" href="#" class="btn export">Reset filters</a>
        </div>
        <!-- temporarily desactivated
        <p class="text-info" style="padding-top:1em">Click on a column header to sort the table</p>-->
      </div>
      <table name="users" class="table table-bordered fixed" style="font-size:8pt">
        <thead>
          <tr>
            <th>EU login Account</th>
            <th style="width:160px">Roles <span style="font-weight:normal;display:block"><input style="width:80px" id="role-filter"/></span></th>
            <th>Personalities <span style="font-weight:normal;display:block"><input style="width:150px" id="user-filter"/></span></th>
            <th style="width:180px">Contact Mails</th>
            <th>Smallest Company Id</th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select="Person"/>
        </tbody>
      </table>
    </div>
  </xsl:template>

  <xsl:template match="Person">
    <tr>
      <td>
        <a data-person="persons/{Id}">
          <xsl:choose>
            <xsl:when test="Remote and (string-length(Remote) &gt; 0)">
              <xsl:value-of select="Remote"/>
            </xsl:when>
            <xsl:when test="Email and (string-length(Email) &gt; 20)">
              <xsl:value-of select="substring(Email,1,20)"/><xsl:text>...</xsl:text>
            </xsl:when>
            <xsl:when test="Email and (string-length(Email) &lt; 21) and (string-length(Email) &gt; 0)">
              <xsl:value-of select="Email"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="Id"/>
            </xsl:otherwise>
          </xsl:choose>
        </a>
      </td>
      <td>
        <xsl:apply-templates select="Personalities" mode="Role"/>
      </td>
      <td>
        <xsl:apply-templates select="Personalities" mode="Name"/>
      </td>
      <td>
        <xsl:apply-templates select="Personalities" mode="Mail"/>
      </td>
      <td>
        <xsl:for-each select="Personalities/AsMember[Company/@Id]">
          <xsl:sort select="number(Company/@Id)"/>
          <xsl:if test="position() = 1">
            <xsl:value-of select="Company/@Id"/>
          </xsl:if>
        </xsl:for-each>
      </td>
    </tr>
  </xsl:template>
  
  <xsl:template match="Personalities" mode="Role">
    <a data-profile="profiles/{../Id}">
      <xsl:apply-templates select="Function"/>
    </a>
  </xsl:template>

  <xsl:template match="Personalities[empty(Function)]" mode="Role">
    <a data-profile="profiles/{../Id}">-</a>
  </xsl:template>
  
  <xsl:template match="Personalities" mode="Name">
    <xsl:apply-templates select="AsMember/Name | Omni/Name"/>
  </xsl:template>

  <xsl:template match="Personalities[empty(AsMember) and empty(Omni)]" mode="Name">
    <span class="fn" style="display:block">? (UNREFERENCED)</span>
  </xsl:template>
  
  <xsl:template match="Personalities" mode="Mail">
    <xsl:apply-templates select="AsMember/Email | Omni/Email"/>
  </xsl:template>
  
  <xsl:template match="Function"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Function[preceding-sibling::Function]" priority="1"><br/><xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="Name">
    <span class="fn" style="display:block">
      <xsl:value-of select="LastName"/><xsl:text> </xsl:text><xsl:value-of select="FirstName"/><xsl:text> </xsl:text>(<xsl:value-of select="../Company"/>)
    </span>
  </xsl:template>

  <xsl:template match="Email">
    <span style="display:block"><xsl:value-of select="."/></span>
  </xsl:template>

</xsl:stylesheet>
