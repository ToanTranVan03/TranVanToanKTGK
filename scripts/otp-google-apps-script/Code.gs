/**
 * TranVanToanKTGK – Gmail OTP delivery using Google Apps Script.
 * Secret is stored in Project Settings -> Script properties -> SHARED_SECRET.
 * Deploy as Web App, Execute as: Me, Who has access: Anyone.
 * Only the .NET backend should know the shared secret.
 */

function doPost(e) {
  try {
    var props = PropertiesService.getScriptProperties();
    var expectedSecret = props.getProperty('SHARED_SECRET');
    if (!expectedSecret || expectedSecret.length < 32) {
      return otpResponse_(false, 'not_configured');
    }
    if (!e || !e.postData || !e.postData.contents || e.postData.length > 4096) {
      return otpResponse_(false, 'invalid_request');
    }

    var input = JSON.parse(e.postData.contents);
    if (typeof input.secret !== 'string' || input.secret !== expectedSecret) {
      return otpResponse_(false, 'unauthorized');
    }

    var recipient = String(input.to || '').trim();
    var code = String(input.code || '').trim();
    var purpose = String(input.purpose || '').trim();

    // Never allow arbitrary message bodies, recipients lists, URLs or attachments.
    if (recipient.length > 254 ||
        !/^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/.test(recipient) ||
        !/^\d{6}$/.test(code)) {
      return otpResponse_(false, 'invalid_payload');
    }

    if (purpose !== 'xác nhận email' && purpose !== 'đăng nhập') {
      return otpResponse_(false, 'invalid_purpose');
    }
    if (MailApp.getRemainingDailyQuota() < 1) {
      return otpResponse_(false, 'quota_exceeded');
    }

    MailApp.sendEmail({
      to: recipient,
      subject: 'TranVanToanKTGK - Mã OTP ' + purpose,
      body: 'Mã OTP ' + purpose + ' của bạn: ' + code + '\n\n' +
            'Không chia sẻ mã này với ai. Mã chỉ dùng trong thời gian ngắn.\n' +
            'Nếu không yêu cầu, bạn có thể bỏ qua email.',
      name: 'TranVanToanKTGK'
    });
    return otpResponse_(true, 'accepted');
  } catch (error) {
    // Do not log request data, email address, shared secret or OTP.
    return otpResponse_(false, 'send_failed');
  }
}

function doGet() {
  return otpResponse_(false, 'post_only');
}

function otpResponse_(ok, status) {
  return ContentService
    .createTextOutput(JSON.stringify({ok: ok, status: status}))
    .setMimeType(ContentService.MimeType.JSON);
}

/** Run once from Apps Script editor and approve MailApp permissions. */
function authorizeMail() {
  var remaining = MailApp.getRemainingDailyQuota();
  if (remaining < 1) {
    throw new Error('Daily Gmail quota exhausted');
  }
  Logger.log('MailApp permission granted; quota is available.');
}
