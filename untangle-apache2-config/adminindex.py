import md5
import uvmlogin
import cgi

from mod_python import apache, Session, util
from psycopg2 import connect

# pages -----------------------------------------------------------------------

def login(req, url=None, realm='Administrator'):
    uvmlogin.setup_gettext()

    options = req.get_options()

    args = util.parse_qs(req.args or '')

    if req.form.has_key('username') or req.form.has_key('password'):
        is_error = True
    else:
        is_error = False

    if req.form.has_key('username') and req.form.has_key('password'):
        username = req.form['username']
        password = req.form['password']

        if _valid_login(req, realm, username, password):
            sess = Session.Session(req)
            sess.set_timeout(uvmlogin.SESSION_TIMEOUT)
            uvmlogin.save_session_user(sess, realm, username)
            sess.save()
            sess.unlock()

            if url == None:
                return apache.OK
            else:
                util.redirect(req, url)

    company_name = uvmlogin.get_company_name()
    title = cgi.escape(_("%s Administrator Login") % company_name)
    host = cgi.escape(req.hostname)

    _write_login_form(req, title, host, is_error)

def logout(req, url=None, realm='Administrator'):
    sess = Session.Session(req)
    sess.set_timeout(uvmlogin.SESSION_TIMEOUT)
    uvmlogin.delete_session_user(sess, realm)
    sess.save()
    sess.unlock()

    if url == None:
        return apache.OK
    else:
        util.redirect(req, url)

# internal methods ------------------------------------------------------------

def _valid_login(req, realm, username, password):
    if realm == 'Administrator' or realm == 'Reports':
        return _admin_valid_login(req, realm, username, password)
    else:
        return False

def _admin_valid_login(req, realm, username, password):
    conn = connect("dbname=uvm user=postgres")
    curs = conn.cursor()

    if realm == 'Administrator':
        q = """ 
SELECT password FROM settings.u_user WHERE login = '%s' AND write_access""" % username
    elif realm == 'Reports':
        q = """
SELECT password FROM settings.u_user WHERE login = '%s' AND reports_access""" % username

    curs.execute(q)
    r = curs.fetchone()

    if r == None:
        uvmlogin.log_login(req, username, False, False, 'U')
        return False
    else:
        pw_hash = r[0]
        raw_pw = pw_hash[0:len(pw_hash) - 8]
        salt = pw_hash[len(pw_hash) - 8:]
        if raw_pw == md5.new(password + salt).digest():
            uvmlogin.log_login(req, username, False, True, None)
            return True
        else:
            uvmlogin.log_login(req, username, False, False, 'P')
            return False

def _write_login_form(req, title, host, is_error):
    login_url = cgi.escape(req.unparsed_uri)
    req.content_type = "text/html; charset=utf-8"
    req.send_http_header()

    if is_error:
        error_msg = '<b style="color:#f00">%s</b><br/><br/>' % cgi.escape(_('Error: Username and Password do not match'))
    else:
        error_msg = ''

    req.write("""\
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<!-- MagicComment: MVTimeout -->

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>%s</title>
<script type="text/javascript">if (top.location!=location) top.location.href=document.location.href;</script>
<style type="text/css">
/* <![CDATA[ */
@import url(/images/base.css);
/* ]]> */
</style>
</head>
<body>
<div id="main" style="width: 500px; margin: 50px auto 0 auto;">
 <div class="main-top-left"></div><div class="main-top-right"></div><div class="main-mid-left"><div class="main-mid-right"><div class="main-mid">
 <!-- Content Start -->

      <center>
        <img alt="" src="/images/BrandingLogo.gif" /><br />

        <b>%s</b><br/>

        <font size="4"><b>%s</b></font>

        <div style="margin: 0 auto; width: 250px; padding: 20px 0 5px;">

        <form method="post" action="%s">
          <table><tbody>
            <tr><td style="text-align:right">%s</td><td><em>&nbsp;%s</em></td></tr>
            <tr><td style="text-align:right">%s</td><td><input id="username" type="text" name="username" value="admin"/></td></tr>
            <tr><td style="text-align:right">%s</td><td><input id="password" type="password" name="password" /></td></tr>
          </tbody></table>
          <br />
          <div style="text-align: center;"><button value="login" type="submit">%s</button></div>
        </form>

        <script type="text/javascript">document.getElementById('password').focus();</script>

        </div>
      </center>


 <!-- Content End -->
 </div></div></div><div class="main-bot-left"></div><div class="main-bot-right"></div>
 <!-- Box End -->
</div>
</body>
</html>""" % (title, error_msg, title, login_url, cgi.escape(_("Server:")), host, cgi.escape(_("Username:")), cgi.escape(_("Password:")), cgi.escape(_("Login"))))
