<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:site="http://oppidoc.com/oppidum/site" xmlns:xt="http://ns.inria.org/xtiger" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/search.xsl"/>
  
  <xsl:template match="XT">
    <xsl:copy-of select="*"/>
  </xsl:template>

  <xsl:template match="Choose">
    <div id="editor" data-template="#">
      <h2>Choose the MS Excel file (.xslx) to import</h2>
      <p>
        <xt:use types="file" label="Test" param="file_URL=import;file_type=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;file_base=import;file_gen_name=auto;file_size_limit=2048;file_button_class=btn btn-primary"/>
      </p>
    </div>
    <xsl:if test="count(List/Unzipped)">
      <xsl:apply-templates select="List"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="List">
    <div id="editor2" data-template="#">
      <h3 class="ecl-heading ecl-heading--h3">Or please choose an existing unpackaged one amongst the following</h3>
      <ul>
        <xsl:for-each select="Unzipped">
          <xsl:variable name="loc">
            <xsl:value-of select="."/>
          </xsl:variable>
          <li>
            <xsl:choose>
              <xsl:when test="@Deref">
                <a href="{$xslt.base-url}events/import?validate={$loc}">
                  <xsl:value-of select="."/>
                </a>
              </xsl:when>
              <xsl:otherwise>
                <a href="{$xslt.base-url}events/import?next={$loc}">
                  <xsl:value-of select="."/>
                </a>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="ancestor::Choose/@Allow = 'delete'">
              <sup> <a href="{$xslt.base-url}events/import?delete={$loc}">Delete</a></sup>
            </xsl:if>
          </li>
        </xsl:for-each>
      </ul>
    </div>
  </xsl:template>

  <!-- FIXME: use model to generate Assert button(s) actually hard-coded in this template rule -->
  <xsl:template match="Validate[not(child::error)]">
    <xsl:variable name="fn">
      <xsl:value-of select="@fn"/>
    </xsl:variable>
    <h2>Call Import Wizard: Data Validation</h2>
    <xsl:apply-templates select="Confirm"/>
    <xsl:apply-templates select="SelectKey"/>
    <div class="row-fluid">
      <div class="span12">
        <h3>Please ensure that all data seem correct before import. Then assert new data against the database</h3>
        <p>The batch contains <xsl:value-of select="count(.//row)"/> rows: <button style="margin-bottom:10px" class="btn btn-primary" data-command="save" data-save-flags="silentErrors" data-replace-target="rdfsd" data-target="editor" data-src="import?fn={$fn}">Assert Events</button></p>
        <div id="editor" data-template="#">
          <xsl:apply-templates select="EnterMetadata"/>
          <xsl:variable name="pos">-1</xsl:variable>
          <table class="table table-bordered">
            <thead>
              <tr>
                <!-- <th><xsl:value-of select="$key"/></th> -->
                <xsl:for-each select=".//headers[position() != $pos]/name">
                  <xsl:variable name="col">
                    <xsl:value-of select="@column"/>
                  </xsl:variable>
                  <xsl:variable name="name">
                    <xsl:value-of select="../../Mapping//Dest[../@Column = $col]/text()"/>
                  </xsl:variable>
                  <th>
                    <xt:use label="{$name}" param="type=checkbox;filter=event;value=on" types="input"/>
                    <xsl:value-of select="."/>
                  </th>
                </xsl:for-each>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="//rows/row">
                <tr>
                  <xsl:for-each select="child::*[position() != $pos]">
                    <td>
                      <xsl:choose>
                        <xsl:when test="string-length(.) > 50"><xsl:value-of select="substring(., 0, 50)"/> [...]</xsl:when>
                        <xsl:otherwise>
                          <xsl:value-of select="."/>
                        </xsl:otherwise>
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

  <xsl:template match="SelectKey">
    <p>Please <span style="font-weight:bold">tick the column</span> that contains the key which relates each individual form to its <span style="font-weight:bold">project number</span>.</p>
  </xsl:template>

  <xsl:template match="EnterMetadata">
    <h3>Please enter/verify all metadata of the event</h3>
    <div class="container">
      <xsl:copy-of select="child::*"/>
    </div>
  </xsl:template>

  <xsl:template match="Confirm">
    <p>The XML file for batch import has already been validated. You can use the button to validate it again (this may take a few minutes if there are a few hundreds lines) or you can directly proceed with the assertion of data below.</p>
    <p>Click <a style="margin-bottom:10px" class="btn btn-small" href="{$xslt.base-url}events/import?validate={ancestor::Validate/@fn}&amp;_confirmed=1">Validate</a> to re-validate data and extract XML rows.</p>
  </xsl:template>

  <xsl:template match="Assert">
    <xsl:variable name="fn">
      <xsl:value-of select="@fn"/>
    </xsl:variable>
    <xsl:variable name="set">
      <xsl:value-of select="@Set"/>
    </xsl:variable>
    <xsl:variable name="tagset">
      <xsl:value-of select="@Tag"/>
    </xsl:variable>
    <xsl:variable name="total">
      <xsl:value-of select="count(//*[local-name() = $tagset])"/>
    </xsl:variable>
    <h2>Events Import Wizard: Assert</h2>
    <div>
      <div class="row-fluid">
        <div class="span12">
          <h3><xsl:value-of select="$set"/> information is complete</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][not(.//MISSING)])"/> of <xsl:value-of select="$total"/>
            <xsl:if test="count(//*[local-name() = $tagset][not(.//MISSING)]) gt 0">
              <a style="margin-left: 15px" class="btn btn-primary" href="{$xslt.base-url}events/import?run={$fn}&amp;set={@Set}">Import <xsl:value-of select="$tagset"/>s</a>
            </xsl:if>
          </p>
        </div>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="Run">
    <h2>Call Import Wizard: Run</h2>
    <div>
      <div class="row-fluid">
        <h2>Results</h2>
        <xsl:apply-templates select="*"/>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="same">
    <li> No need to re-import event metadata file (<xsl:value-of select="."/>)</li>
  </xsl:template>
  
  <xsl:template match="created[Template]">
    <li> Created metadata for event "<xsl:value-of select="Information/Name"/>" (#<xsl:value-of select="string(@key)"/>) with template "<xsl:value-of select="Template"/>" and project key tag "<xsl:value-of select="Template/@ProjectKeyTag"/>"</li>
  </xsl:template>
  
  <xsl:template match="skipped[Template]">
    <li> Skipped creation of metadata for event "<xsl:value-of select="Information/Name"/>" (#<xsl:value-of select="string(@key)"/>) with template "<xsl:value-of select="Template"/>" and project key tag "<xsl:value-of select="Template/@ProjectKeyTag"/>"</li>
  </xsl:template>

  <xsl:template match="updated">
    <li> Updated event data in companies for key <xsl:value-of select="./*[@Key]/text()"/></li>
  </xsl:template>

  <xsl:template match="failed">
    <li> Failed with reason <xsl:value-of select="@reason"/>
    </li>
  </xsl:template>

  <xsl:template match="skipped">
    <li> Skipped because <xsl:value-of select="@reason"/> : <xsl:value-of select="."/>
    </li>
  </xsl:template>
  
  <xsl:template match="Invalidate">
    <li> Invalidate cache for <xsl:value-of select="."/>
    </li>
  </xsl:template>

  <xsl:template match="NoCache">
    <li> No cache for <xsl:value-of select="."/>
    </li>
  </xsl:template>

</xsl:stylesheet>
