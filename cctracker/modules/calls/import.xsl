<?xml version="1.0" encoding="UTF-8"?>

<!-- CCTRACKER - EIC Case Tracker Application
  
     Author: Stéphane Sire <s.sire@opppidoc.fr>
     
     Cases exportation facility
     
     April 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">
  
  <xsl:param name="xslt.base-url">/</xsl:param>
  
  <!-- TODO: add <site:title> for window title when skin handles pure text() -->
  <xsl:template match="/">
    <site:view skin="axel">
      <site:window><title>Call Import Wizard</title></site:window>
      <site:content>
        <xsl:apply-templates select="Patch |Choose | Validate | Broken | Run"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Patch">
    <h2>Patch</h2>
<pre>
  <xsl:copy-of select="*"/>
</pre>
  </xsl:template>
  
  <xsl:template match="Choose">
    <h1>Call Import Wizard</h1>
    <div id="editor" data-template="#" style="padding:10px">
      <h2>Choose the MS Excel file (.xslx) to import</h2>
      <p>
        <xt:use types="file" label="Test" param="file_URL=import;file_type=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;file_base=import;file_gen_name=auto;file_size_limit=1024;file_button_class=btn btn-primary"></xt:use>
      </p>
    </div>
    <xsl:if test="count(List/Unzipped)">
      <xsl:apply-templates select="List"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="List">
    <div id="editor2" data-template="#" style="padding:10px">
      <h2>Or please choose an existing unpackaged one amongst the following</h2>
      <ul>
        <xsl:for-each select="Unzipped">
          <xsl:variable name="loc"><xsl:value-of select="."/></xsl:variable>
          <li>
            <xsl:choose>
              <xsl:when test="@Deref">
                <a href="{$xslt.base-url}import?validate={$loc}"><xsl:value-of select="."/></a>
              </xsl:when>
              <xsl:otherwise>
                <a href="{$xslt.base-url}import?next={$loc}"><xsl:value-of select="."/></a>
              </xsl:otherwise>
            </xsl:choose>
          </li>
        </xsl:for-each>
      </ul>
    </div>
  </xsl:template>
  
  <xsl:template match="Validate[not(child::error)]">
    <xsl:variable name="fn"><xsl:value-of select="@fn"/></xsl:variable>
    <h1>Call Import Wizard: Data Validation</h1>
    <div style="padding:10px">
      <h2>Extracted Metadata</h2>
      <div class="row-fluid">
        <div class="span6">
          <table class="table table-bordered">
            <xsl:for-each select="rows/metadata/child::*">
              <tr><td><xsl:value-of select="local-name(.)"/></td><td><xsl:value-of select="."/></td></tr>
            </xsl:for-each>
          </table></div></div>
      <h2>Please ensure that all data seem correct before import. Then assert new data against the database</h2>
      <a style="margin-bottom:10px" class="btn btn-primary" href="{$xslt.base-url}import?assert={$fn}">Assert</a>
      <div class="row-fluid">
        <div class="span6">
          <xsl:variable name="key"><xsl:value-of select="Mapping/Entry[@Key]/Src/text()"/></xsl:variable>
          <xsl:variable name="pos"><xsl:value-of select="count(Mapping/Entry[@Key]/preceding-sibling::*) + 1"/></xsl:variable>
          <table class="table table-bordered">
            <thead>
              <tr>
                <th><xsl:value-of select="$key"/></th>
                <xsl:for-each select="Mapping/Entry[position() != $pos]/Src">
                  <th><xsl:value-of select="."/></th>
                </xsl:for-each>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="rows/row">
                <tr>
                  <td><xsl:value-of select="child::*[position() = $pos]"/></td>
                  <xsl:for-each select="child::*[position() != $pos]">
                    <td>
                      <xsl:choose>
                        <xsl:when test="string-length(.) > 50"><xsl:value-of select="substring(.,0,50)"/> [...]</xsl:when>
                        <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                      </xsl:choose>
                    </td>
                  </xsl:for-each>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="Broken[not(descendant-or-self::MISSING)]">
    <xsl:variable name="fn"><xsl:value-of select="@fn"/></xsl:variable>
    <h1>Call Import Wizard: Assert</h1>
    <div style="padding:10px">
      <div class="row-fluid">
        <div class="span6">
          <h2>Everything looks fine :)</h2>
          <a class="btn btn-primary" href="{$xslt.base-url}import?run={$fn}">Push me!</a>
        </div>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="Broken[descendant-or-self::MISSING]">
    <h1>Call Import Wizard: Assert</h1>
    <div style="padding:10px">
      <div class="row-fluid">
        <div class="span6">
          <h2>Please fix the following items and refresh the page</h2>
          <h2>Missing Officer(s) (will be created automatically)</h2>
          <ul>
            <xsl:for-each select="//MISSING[@Name = 'ProjectOfficer']">
              <li><xsl:value-of select="."/></li>
            </xsl:for-each>
          </ul>
          <h2>Missing Call Topic (must be updated <b>by hands</b>)</h2>
          <ul>
            <xsl:for-each select="//MISSING[@Name = 'CallTopic']">
              <li><xsl:value-of select="."/></li>
            </xsl:for-each>
          </ul>
          <h2>Missing Country Code(s) (must be updated <b>by hands</b>)</h2>
          <ul>
            <xsl:for-each select="//MISSING[@Name = 'Country']">
              <li><xsl:value-of select="."/></li>
            </xsl:for-each>
          </ul>
        </div>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="Run">
    <h1>Call Import Wizard: Run</h1>
    <div style="padding:10px">
      <div class="row-fluid">
        <h2>Results</h2>
        <xsl:apply-templates select="Skip | Extra | First | Created | Failed | FailedColl | Invalidate | NoCache"/>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="Skip">
    <xsl:variable name="caseno"><xsl:value-of select="Former"/></xsl:variable>
    <li>
      Skip creation of project <xsl:value-of select="Ac"/> with Id <xsl:value-of select="Id"/> of beneficiary  <xsl:value-of select="Company"/> because it already exists as case <a href="cases/{$caseno}"><xsl:value-of select="Former"/></a>
    </li>
  </xsl:template>
  
  <xsl:template match="Extra">
    <li>
      Create an extra project <xsl:value-of select="Ac"/> for <xsl:value-of select="Ent"/> with PIC <xsl:value-of select="PIC"/>
    </li>
  </xsl:template>
  
  <xsl:template match="First">
    <li>
      Create a first project <xsl:value-of select="Ac"/> for <xsl:value-of select="Ent"/> with PIC <xsl:value-of select="PIC"/>
    </li>
  </xsl:template>
  
  <xsl:template match="Created">
    <xsl:variable name="caseno"><xsl:value-of select="CaseNo"/></xsl:variable>
    <li>
      Created case <xsl:value-of select="Ac"/> as <a href="cases/{$caseno}"><xsl:value-of select="CaseNo"/></a> into <xsl:value-of select="CaseURI"/>
    </li>
  </xsl:template>
  
  <xsl:template match="Failed">
    <li>
      Failed to store case <xsl:value-of select="Ac"/> with Project Id <xsl:value-of select="ProjectId"/> into <xsl:value-of select="CaseURI"/>
    </li>
  </xsl:template>
  
  <xsl:template match="FailedColl">
    <xsl:variable name="caseno"><xsl:value-of select="CaseNo"/></xsl:variable>
    <li>
      Failed to create container for case <xsl:value-of select="Ac"/> with Project Id <xsl:value-of select="ProjectId"/> into <xsl:value-of select="CaseURI"/>
    </li>
  </xsl:template>
  
  <xsl:template match="Invalidate">
    <li>
      Invalidate cache for <xsl:value-of select="."/>
    </li>
  </xsl:template>
  
  <xsl:template match="NoCache">
    <li>
      No cache for <xsl:value-of select="."/>
    </li>
  </xsl:template>
  
</xsl:stylesheet>
