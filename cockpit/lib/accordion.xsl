<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <!--*********************-->
  <!--***** Accordion *****-->
  <!--*********************-->

  <xsl:template match="Accordion">
    <div class="accordion">
      <xsl:apply-templates select="Document | Drawer"/>
    </div>
  </xsl:template>

  <xsl:template name="document-title">
    <div>
      <h3 class="c-document-title">
        <xsl:if test="SubTitle">
          <xsl:attribute name="style">display:inline</xsl:attribute>
        </xsl:if>
        <a class="c-accordion-toggle" data-toggle="collapse" href="#collapse-{@Id}">
          <xsl:copy-of select="Name/@loc"/>
          <xsl:value-of select="Name"/>
        </a>
      </h3>
      <xsl:apply-templates select="SubTitle" mode="document"/>
    </div>
  </xsl:template>

  <xsl:template match="SubTitle" mode="document">
    <p class="text-info"><xsl:copy-of select="@style"/><xsl:value-of select="."/></p>
  </xsl:template>

  <!-- Display documents into workflow using their XTiger XML template 
       TODO: improve autoscroll so that it does not need data-autoscroll-shift hint  -->
  <xsl:template match="Document[not(@Status) or @Status = 'on']">
    <xsl:variable name="autoscroll">
      <xsl:if test="@data-autoscroll-shift"> autoscroll</xsl:if>
    </xsl:variable>
    <xsl:variable name="opened">
      <xsl:if test="@data-accordion-status = 'opened'"> in</xsl:if>
    </xsl:variable>
    <div class="accordion-group c-documents" data-command="accordion" data-target="c-editor-{@Id}"
      data-target-ui="c-editor-{@Id}-menu" data-with-template="{Template}">
      <xsl:copy-of select="@data-accordion-status"/>
      <xsl:apply-templates select="Resource" mode="data-src"/>
      <div class="accordion-heading c-{@Status} c-active {@class}">
        <span class="c-document-menu c-menu-scope"><xsl:apply-templates select="Actions/*[local-name(.) != 'Spawn']"/></span>
        <span id="c-editor-{@Id}-menu" class="c-editor-menu c-menu-scope">
          <xsl:apply-templates select="Actions/Edit" mode="menubar"/>
        </span>
        <xsl:call-template name="document-title"/>
      </div>
      <div id="collapse-{@Id}" class="accordion-body collapse{$opened}">
        <div class="accordion-inner">
          <div id="c-editor-{@Id}-errors" class="alert alert-error af-validation"></div>
          <div id="c-editor-{@Id}" class="c-autofill-border" data-command="transform{$autoscroll}"
            data-validation-output="c-editor-{@Id}-errors" data-validation-label="label">
            <xsl:copy-of select="@data-autoscroll-shift"/>
            <xsl:copy-of select="Actions/Edit/@data-no-validation-inside"/>
            <noscript loc="app.message.js">Activez Javascript</noscript>
            <p loc="app.message.loading">Chargement du masque en cours</p>
          </div>
          <!-- duplicated bottom editor menu (conventional -bottom suffix) -->
          <div id="c-editor-{@Id}-menu-bottom" class="c-menu-scope c-editor-menu">
            <xsl:apply-templates select="Actions/Edit" mode="menubar"/>
          </div>
        </div>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="Document[@Status = 'off']">
    <xsl:variable name="autoscroll">
      <xsl:if test="@data-autoscroll-shift"> autoscroll</xsl:if>
    </xsl:variable>
    <xsl:variable name="opened">
      <xsl:if test="@data-accordion-status = 'opened'"> in</xsl:if>
    </xsl:variable>
    <div class="accordion-group c-documents" >
      <div class="accordion-heading c-{@Status} c-inactive {@class}">
        <xsl:call-template name="document-title"/>
      </div>
    </div>
  </xsl:template>
  
  <!-- Generates editing menu
       FIXME: currently @Forward assumes Resources ends-up with a ?something parameter (goal)
       -->
  <xsl:template match="Edit" mode="menubar">
    <xsl:if test="@Forward = 'submit'">
      <button class="btn btn-primary"
        data-command="save c-inhibit"
        data-save-flags="silentErrors"
        data-target="c-editor-{ancestor::Document/@Id}"
        data-replace-type="event"
        loc="action.submit">
        <xsl:attribute name="data-src">
          <xsl:value-of select="/Page/@ResourceName"/>/<xsl:value-of select="substring-before(ancestor::Document/Resource, '?')"/>?submit<xsl:if test="@To != ''">&amp;to=<xsl:value-of select="@To"/></xsl:if>
        </xsl:attribute>
        <xsl:value-of select="@Forward"/>
      </button>
    </xsl:if>
    <button class="btn btn-primary"
      data-command="save c-inhibit"
      data-save-flags="silentErrors"
      data-target="c-editor-{ancestor::Document/@Id}"
      data-replace-type="event"
      loc="action.save"
      >Enregistrer</button>
    <button class="btn"
      data-command="trigger"
      data-target="c-editor-{ancestor::Document/@Id}"
      data-trigger-event="axel-cancel-edit"
      loc="action.cancel"
      >Annuler</button>
  </xsl:template> 

  <!-- Document w/o associated editor (direct visualization of inline items, e.g. closed Logbook) -->
  <xsl:template match="Document[not(Template) and not(Resource)]">
    <div class="accordion-group c-documents">
      <div class="accordion-heading c-{@Status}">
        <xsl:call-template name="document-title"/>
      </div>
      <div id="collapse-{@Id}" class="accordion-body collapse">
        <div class="accordion-inner">
          <xsl:apply-templates select="Content/*"/>
        </div>
      </div>
    </div>
  </xsl:template>

  <!-- TO BE REWRITTEN for Cockpit - EIC SME Dashboard Application -->
  <!-- Document with Drawer action to manage the creation of a read-only collection of (small) associated documents
       Currently the Document cannot have it's own editable representation (this is left as a future extension)
  
       NOTE: this is different than a Drawer directly inside a Tab (see above) -->
  <xsl:template match="Document[Actions/Drawer]">
    <div class="accordion-group c-documents">
      <div class="accordion-heading c-{@Status}">
        <span class="c-document-menu c-menu-scope"><xsl:apply-templates select="Actions/*"/></span>
        <xsl:call-template name="document-title"/>
      </div>
      <div id="collapse-{@Id}" class="accordion-body collapse">
        <div class="accordion-inner">
          <div id="c-drawer-{@Id}" class="collapse c-drawer" data-command="acc-drawer"
            data-target="c-editor-{@Id}" data-drawer-trigger="c-drawer-{@Id}-action">
            <div id="c-editor-{@Id}" class="c-autofill-border" data-command="transform"
              data-validation-output="c-editor-{@Id}-errors" data-validation-label="label">
              <noscript loc="app.message.js">Activez Javascript</noscript>
              <p loc="app.message.loading">Chargement du masque en cours</p>
            </div>
            <div id="c-editor-{@Id}-errors" class="alert alert-error af-validation"> </div>
            <div id="c-editor-{@Id}-menu" class="c-editor-menu c-menu-scope">
              <button class="btn btn-primary"
                data-command="save c-inhibit"
                data-save-flags="silentErrors"
                data-target="c-editor-{@Id}"
                loc="action.save">
                <xsl:choose>
                  <xsl:when test="Actions/Drawer/@AppenderId">
                    <xsl:attribute name="data-replace-type">append</xsl:attribute>
                    <xsl:attribute name="data-replace-target"><xsl:value-of
                        select="Actions/Drawer/@AppenderId"/></xsl:attribute>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:attribute name="data-replace-type">event</xsl:attribute>
                  </xsl:otherwise>
                </xsl:choose>
                Enregistrer
              </button>
              <button class="btn"
                data-command="trigger"
                data-trigger-event="axel-cancel-edit"
                data-target="c-editor-{@Id}"
                loc="action.cancel">
                Annuler
              </button>
            </div>
          </div>
          <xsl:apply-templates select="Content/*"/>
        </div>
      </div>
    </div>
  </xsl:template>
  
  <!--******************-->
  <!--***** Drawer *****-->
  <!--******************-->
  
  <!-- Top level Drawer
       TODO: version that can be used in-place of a Document inside an Accordion-->
  <xsl:template match="Drawer">
    <xsl:variable name="Id">
      <xsl:value-of select="@Id"/>
    </xsl:variable>
    <div class="accordion">
      <div class="accordion-group c-drawer" data-command="drawer" data-target="c-editor-{$Id}">
        <div class="accordion-heading {@class}">
          <span class="c-document-menu c-perm-menu">
            <xsl:apply-templates select="Actions/*"/>
          </span>
          <h2 style="margin-bottom:0">
            <xsl:copy-of select="Title/@loc"/>
            <xsl:value-of select="Title"/>
          </h2>
          <p style="margin-top:0"><i><xsl:value-of select="SubTitle"/></i></p>
        </div>
        <div id="collapse-{$Id}" class="accordion-body collapse">
          <div class="accordion-inner c-editing-mode">
            <div id="c-editor-{$Id}" class="c-autofill-border c-document-editor"
              data-command="transform" data-validation-output="c-editor-{$Id}-errors"
              data-validation-label="label">
              <noscript loc="app.message.js">Activez Javascript</noscript>
              <p loc="app.message.loading">Chargement du masque en cours</p>
            </div>
            <div id="c-editor-{$Id}-errors" class="alert alert-error af-validation"> </div>
            <div id="c-editor-{$Id}-menu" class="c-editor-menu c-menu-scope">
              <button class="btn btn-primary"
                data-command="save c-inhibit"
                data-save-flags="silentErrors"
                data-target="c-editor-{$Id}"
                loc="action.save">
                <xsl:choose>
                  <xsl:when test="@AppenderId">
                    <xsl:attribute name="data-replace-type">append</xsl:attribute>
                    <xsl:attribute name="data-replace-target"><xsl:value-of select="@AppenderId"/></xsl:attribute>
                  </xsl:when>
                  <xsl:when test="@PrependerId">
                    <xsl:attribute name="data-replace-type">prepend</xsl:attribute>
                    <xsl:attribute name="data-replace-target"><xsl:value-of select="@PrependerId"
                      /></xsl:attribute>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:attribute name="data-replace-type">event</xsl:attribute>
                  </xsl:otherwise>
                </xsl:choose>
                Enregistrer
              </button>
              <button class="btn"
                data-command="trigger"
                data-target="c-editor-{$Id}"
                data-trigger-event="axel-cancel-edit"
                loc="action.cancel">
                Annuler
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </xsl:template>

  <!--*************-->
  <!--** Actions **-->
  <!--*************-->

  <!-- Accordion 'edit' action to edits the given Resource with a given Template -->
  <!-- TODO: adapt ! -->
  <xsl:template match="Actions/Drawer">
    <xsl:variable name="Id">
      <xsl:value-of select="ancestor::Document/@Id"/>
    </xsl:variable>
    <button id="c-drawer-{$Id}-action" class="btn btn-primary"
      data-command="edit"
      data-edit-action="create"
      data-with-template="{Template}"
      data-command-ui="disable"
      data-target="c-editor-{$Id}"
      data-target-ui="c-editor-{$Id}-menu"
      loc="{@loc}">
      <xsl:apply-templates select="Controller" mode="data-src"/>
      <xsl:apply-templates select="Initialize" mode="data-init"/>
      Command
    </button>
  </xsl:template>

  <!-- Accordion 'edit' action to edits the given Resource with a given Template -->
  <xsl:template match="Edit">
    <button class="btn btn-primary"
      data-command="edit"
      data-edit-action="update"
      data-command-ui="hide"
      data-with-template="{Template}"
      data-target="c-editor-{../../@Id}"
      data-target-ui="c-editor-{../../@Id}-menu">
      <xsl:attribute name="loc">
        <xsl:choose>
          <xsl:when test="@loc"><xsl:value-of select="@loc"/></xsl:when>
          <xsl:otherwise>action.edit</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates select="Resource" mode="data-src"/>
      Éditer
    </button>
  </xsl:template>
  
  <!-- Pseudo-AXEL in place template to use 'c-delete' command -->
  <xsl:template match="Delete">
    <button class="btn btn-primary"
      data-command="c-delete c-inhibit"
      data-template="#"
      data-controller="{/Page/@ResourceName}/{.}"
      loc="action.delete">
      Supprimer
    </button>
  </xsl:template>
  
  <!-- Drawer 'edit' action to create a new resource from a Drawer -->
  <xsl:template match="Drawer/Actions/Edit">
    <xsl:variable name="Id">
      <xsl:value-of select="ancestor::Drawer/@Id"/>
    </xsl:variable>
    <button class="btn btn-primary"
      data-command="edit"
      data-edit-action="create"
      data-with-template="{Template}" 
      data-src="{Controller}"
      data-target="c-editor-{$Id}"
      data-target-ui="c-editor-{$Id}-menu"
      >
      <xsl:apply-templates select="Initialize" mode="data-init"/>
      <xsl:apply-templates select="Label"/>
    </button>
  </xsl:template>

  <!--**********************************-->
  <!--*****  Change status action  *****-->
  <!--**********************************-->
  
  <!-- Status change menu reduced to a single command button
       The single Status model MUST define a Label attribute (no i18n yet)
       Does not support the @Id attribute on the single Status command
       NOTE: implies <done/> Ajax response since it does not configure e-mail modal window
  
       TODO: support for multiple different data-confirm-loc 
    -->
  <xsl:template match="ChangeStatus[@Status][count(Status) = 1]" priority="1">
    <button class="btn btn-primary"
      data-command="status c-inhibit"
      data-target="{@TargetEditor}" 
      data-status-from="{@Status}" 
      data-status-ctrl="{/Page/@ResourceName}/status"
      data-action="{Status/@Action}">
      <xsl:apply-templates select="@Id"/>
      <xsl:attribute name="data-confirm-loc">
        <xsl:choose>
          <xsl:when test="Status/@data-confirm-loc">
            <xsl:value-of select="Status/@data-confirm-loc[1]"/>
          </xsl:when>
          <xsl:otherwise>confirm.status.change</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates select="Status/@Argument"/>
      <xsl:value-of select="Status/@Label"/>
    </button>
  </xsl:template>

  <!-- Status change drop down with optional e-mail modal window configuration  -->
  <xsl:template match="ChangeStatus[@Status]">
    <xsl:variable name="editor">
      <xsl:value-of select="@TargetEditor"/>
    </xsl:variable>
    <div class="btn-group pull-right" style="margin-left:10px">
      <a class="btn btn-success dropdown-toggle" data-toggle="dropdown" href="#" style="outline:none">
          <span loc="action.status.change">Status</span>
          <span class="caret"/>
      </a>
      <ul class="dropdown-menu"
        data-command="status c-inhibit" 
        data-target="{@TargetEditor}" 
        data-status-from="{@Status}"
        data-status-ctrl="{/Page/@ResourceName}/status"
        data-confirm-loc="confirm.status.change">
        <xsl:apply-templates select="@Id"/>
        <xsl:apply-templates select="@TargetEditor" mode="data-target-modal"/>
        <xsl:apply-templates select="/Page/Modals/Modal[@Id = $editor]/Template" mode="data-with-template"/>
        <xsl:apply-templates select="/Page/Modals/Modal[@Id = $editor]/Initialize" mode="data-init"/>
        <xsl:apply-templates select="/Page/Modals/Modal[@Id = $editor]/Controller" mode="data-src"/>
        <xsl:apply-templates select="../Spawn" mode="change-status"/>
        <xsl:apply-templates select="Status" mode="change-status"/>
      </ul>
    </div>
  </xsl:template>

  <!-- Generates pseudo-status change menu with only one option to spawn an activity  
       NOT USED in cockpit - imported from initial workflow.xsl in XCM -->
  <xsl:template match="ChangeStatus[not(@Status) and ../Spawn]" priority="1">
    <div class="btn-group pull-right" style="margin-left:10px">
      <a class="btn btn-success dropdown-toggle" data-toggle="dropdown" href="#" style="outline:none">
          <span loc="action.status.change">Status</span>
          <span class="caret"/>
      </a>
      <ul class="dropdown-menu">
        <xsl:apply-templates select="@Id"/>
        <xsl:apply-templates select="../Spawn" mode="change-status"/>
      </ul>
    </div>
  </xsl:template>

  <!-- No menu 
       NOT USED in cockpit - imported from initial workflow.xsl in XCM -->
  <xsl:template match="ChangeStatus[not(@Status) and not(../Spawn)]" priority="1">
  </xsl:template>

  <!-- TODO: use Dictionary > Transitions to localize @Label  -->
  <xsl:template match="Status" mode="change-status">
    <xsl:variable name="to" select="string(@To)"/>
    <li>
      <a tabindex="-1" href="#" data-action="{@Action}">
        <xsl:apply-templates select="@Argument"/>
        <xsl:apply-templates select="@Id"/>
        <xsl:choose>
          <xsl:when test="@Label"><xsl:value-of select="@Label"/>
          </xsl:when>
          <xsl:when test="number(parent::ChangeStatus/@Status) &lt; number($to)">
            <xsl:apply-templates select="@Intent"/>Advance to “<xsl:value-of select="/Page/Dictionary/WorkflowStatus/Option[Value = $to]/Name"/>”
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="@Intent"/>Return to “<xsl:value-of select="/Page/Dictionary/WorkflowStatus/Option[Value = $to]/Name"/>”
          </xsl:otherwise>
        </xsl:choose>
      </a>
    </li>
  </xsl:template>

  <xsl:template match="@Argument"><xsl:attribute name="data-argument"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@Intent[. = 'accept']"><xsl:text>Accept and </xsl:text>
  </xsl:template>

  <xsl:template match="@Intent[. = 'refuse']"><xsl:text>Reject and </xsl:text>
  </xsl:template>

  <xsl:template match="Spawn"  mode="change-status">
    <li>
      <a tabindex="-1" href="#" data-command="confirm" data-src="{/Page/@ResourceName}/{Controller}"><xsl:apply-templates select="@Id"/>Create new coaching activity</a>
    </li>
  </xsl:template>

</xsl:stylesheet>
