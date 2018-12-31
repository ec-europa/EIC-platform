<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach Match acceptance rendering

     June 2016 - (c) Copyright may be reserved
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">
  
  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="CoachManagement">
    <div class="tabbable">
      <ul class="nav nav-tabs" id="nav-accr">
        <li class="active"><a href="#c-pane-applicant" data-toggle="tab">Applicants</a></li>
        <li><a href="#c-pane-accepted" data-toggle="tab">Accepted</a></li>
        <li><a href="#c-pane-deleted" data-toggle="tab">Rejected/Removed</a></li>
        <li><a href="{$xslt.base-url}acceptances" class="export">Go to export view</a></li>
      </ul>
      <div class="tab-content">
        <div class="tab-pane active" id="c-pane-applicant">
          <h2 id="cm-newacc">New requests for acceptance</h2>
          <table id="cm-host-applicant-results" host="{HostRef}" who="{@UID}" class="table table-bordered" data-command="host-applicant-table" data-table-configure="sort filter">
            <thead>
              <tr>
                <th data-sort="Name" data-filter="Name"><span class="head">Applicant Coach</span> (<span class="cm-host-applicant-counter">0</span>)<br/><input type="text" style="max-width:100px"/></th>
                <th data-sort="-AccDate"><span class="head">Date of Application</span></th>
                <th>Acceptance status</th>
                <th>Contact person</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
            </tbody>
          </table>
          <p id="cm-host-applicant-complete" style="text-align:center;display:none">Complete</p>
        </div>
        <div class="tab-pane" id="c-pane-accepted">
          <h2 id="cm-acc">Accepted Coaches</h2>
          <table id="cm-host-accepted-results" host="{HostRef}" who="{@UID}" class="table table-bordered" data-command="host-accepted-table" data-table-configure="sort">
            <thead>
              <tr>
                <th data-sort="Name"><span class="head">Coach</span> (<span class="cm-host-accepted-counter">0</span>)<br/><input type="text" style="max-width:100px"/></th>
                <th>Notes</th>
                <th data-sort="-AccDate"><span class="head">Acceptance status</span></th>
                <th>Working status</th>
                <th>Contact person</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
            </tbody>
          </table>
          <p id="cm-host-accepted-complete" style="text-align:center;display:none">Complete</p>
        </div>
        <div class="tab-pane" id="c-pane-deleted">
          <h2 id="cm-remrej">Removed/Rejected Coaches</h2>
          <table id="cm-host-deleted-results" host="{HostRef}" who="{@UID}" class="table table-bordered" data-command="host-deleted-table" data-table-configure="sort">
            <thead>
              <tr>
                <th data-sort="Name"><span class="head">Coach</span> (<span class="cm-host-deleted-counter">0</span>)<br/><input type="text" style="max-width:100px"/></th>
                <th>Notes</th>
                <th data-sort="-AccDate"><span class="head">Acceptance status</span></th>
                <th>Working status</th>
                <th>Contact person</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
            </tbody>
          </table>
          <p id="cm-host-deleted-complete" style="text-align:center;display:none">Complete</p>
        </div>
      </div>
    </div>
  </xsl:template>
</xsl:stylesheet>
