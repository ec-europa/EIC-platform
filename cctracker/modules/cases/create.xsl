<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/">
    <xsl:apply-templates select="Display"/>
  </xsl:template>

  <xsl:template match="Display">
    <site:view skin="case">
      <site:window><title loc="case.title.create">Title</title></site:window>
      <site:title>
        <h1 loc="case.title.create">Title</h1>
      </site:title>
      <site:content>
        <xsl:apply-templates select="Case"/>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Case[@Editor='true']">
    <div class="row-fluid">
      <div id="c-editor-errors" class="span12 alert alert-error af-validation">
      </div>
    </div>
    <div data-axel-base="{$xslt.base-url}" id="editor" class="c-autofill-border c-editing-mode" data-template="{Template}" data-validation-output="c-editor-errors" data-validation-label="label">
      <xsl:apply-templates select="Resource"/>
      <noscript loc="app.message.js">Activez Javascript</noscript>
      <p loc="app.message.loading">Chargement du masque en cours</p>
    </div>
    <div class="row-fluid">
      <div class="span12 c-menu-scope" style="text-align:right; margin-top: 10px">
        <button class="btn btn-primary" data-command="save c-inhibit" data-target="editor" data-save-confirm="Confirmez-vous l'enregistrement du cas ?" data-save-confirm-loc="case.dialog.confirm" loc="action.save">Enregistrer</button>
        <xsl:apply-templates select="Cancel"/>
        <button class="btn btn-small" data-command="reset" data-target="editor" loc="action.reset">Effacer</button>
      </div>
    </div>
  </xsl:template>

  <!-- FIXME : to be moved to workflow.xsl to manage Case activities in Case tab (!) -->
  <xsl:template match="Activities">
    <div>
      <div class="row-fluid">
        <div class="span12">
          <xsl:if test="Add">
            <div style="float:right">
              <button class="btn btn-primary" data-command="add" data-target-modal="activity-modal" data-target="activity-editor" loc="action.create.activity">Créer une activité</button>
            </div>
          </xsl:if>
          <h3 loc="case.title.activities">Liste des activités</h3>
          <xsl:if test="count(Activity) > 0">
            <table class="table table-bordered">
              <thead>
                <tr>
                  <th loc="term.title">Titre</th>
                  <th loc="term.coach">Coach</th> 
                  <th loc="term.creationDate">Date de création</th>
                  <th loc="term.phase">Phase</th>
                  <th loc="term.service">Service</th>
                  <th loc="term.status">Statut</th>
                </tr>
              </thead>
              <tbody id="activities">
                <xsl:apply-templates select="Activity"/>
              </tbody>
            </table>
          </xsl:if>
        </div>
      </div>
    </div>
    <xsl:apply-templates select="Add"/>
  </xsl:template>

  <xsl:template match="Resource">
    <xsl:attribute name="data-src"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Delete">
    <button class="btn btn-primary top-action" data-command="c-delete" data-template="#" data-controller="{.}" loc="action.delete">Supprimer</button>
  </xsl:template>

  <xsl:template match="Edit">
    <a class="btn btn-primary top-action" href="{.}" loc="action.edit">Modifier</a>
  </xsl:template>

  <xsl:template match="Cancel">
    <a class="btn" href="{.}" loc="action.cancel">Annuler</a>
  </xsl:template>

  <!-- Button to open the activity editor and activity editor modal window -->
  <xsl:template match="Add">
    <div id="activity-modal" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="label-activity" aria-hidden="true" data-backdrop="static">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
        <h2 loc="form.title.activity.create">Création d'une nouvelle activité</h2>
      </div>
      <div class="modal-body" id="activity-editor" data-command="transform" data-template="{Template}" data-validation-output="activity-errors" data-validation-label="label">
      </div>
      <div class="modal-footer c-menu-scope">
        <div id="activity-errors" class="alert alert-error af-validation">
          <button type="button" class="close" data-dismiss="alert">x</button>
        </div>        
        <button class="btn btn-primary" data-command="save c-inhibit" data-target="activity-editor" data-replace-target="activities" data-replace-type="append" data-src="{Controller}" loc="action.save">Enregistrer</button>
        <button class="btn" data-command="trigger" data-target="activity-editor" data-trigger-event="axel-cancel-edit" loc="action.cancel">Annuler</button>
        <button class="btn btn-small" data-command="reset" data-target="activity-editor" loc="action.reset">Effacer</button>
      </div>
    </div>
  </xsl:template>
</xsl:stylesheet>
