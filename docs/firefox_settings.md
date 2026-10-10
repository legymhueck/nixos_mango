# Firefox settings

```sh
programs.firefox = {
    enable = true;
    languagePacks = [ "de" ];
    preferencesStatus = "default";

    preferences = {
      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
      "privacy.trackingprotection.emailtracking.enabled" = true;
      "privacy.donottrackheader.enabled" = true;

      "dom.security.https_only_mode" = true;
      "dom.security.https_only_mode_pbm" = true;

      "toolkit.telemetry.unified" = false;
      "toolkit.telemetry.archive.enabled" = false;
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "app.shield.optoutstudies.enabled" = false;

      "geo.enabled" = false;
      "browser.search.suggest.enabled" = false;
      "browser.tabs.closeWindowWithLastTab" = false;

      "sidebar.revamp" = true;
      "sidebar.verticalTabs" = false;

      "browser.startup.page" = 1;
      "browser.startup.homepage" = "about:blank";
      "browser.newtabpage.enabled" = false;

      "browser.newtabpage.activity-stream.showWeather" = false;
      "browser.newtabpage.activity-stream.showSponsored" = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.activity-stream.feeds.telemetry" = false;

      "browser.aboutwelcome.enabled" = false;
      "trailhead.firstrun.didSeeAboutWelcome" = true;
      "browser.startup.homepage_override.mstone" = "ignore";
      "browser.shell.checkDefaultBrowser" = false;
      "datareporting.policy.dataSubmissionPolicyBypassNotification" = true;
    };

    policies = {
      DisableFirefoxStudies = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DontCheckDefaultBrowser = true;

      Homepage = {
        URL = "about:blank";
        StartPage = "homepage";
        Locked = true;
      };

      NewTabPage = false;
      DisableProfileImport = true;

      ManagedBookmarks = [
        { toplevel_name = "Schule"; }
        { name = "Scratch"; url = "https://scratch.mit.edu/"; }
        { name = "Microsoft 365"; url = "https://m365.cloud.microsoft/"; }
        { name = "Gymnasium Hückelhoven"; url = "https://www.gymnasium-hueckelhoven.de/"; }
        { name = "Logineon NRW LMS"; url = "https://167642.logineonrw-lms.de/"; }
        {
          name = "WebUntis";
          url = "https://gym-huckelhoven.webuntis.com/WebUntis/?school=gym-huckelhoven#/basic/login";
        }
      ];

      SearchEngines = {
        Add = [
          {
            Name = "DuckDuckGo";
            URLTemplate = "https://duckduckgo.com/?q={searchTerms}";
            Method = "GET";
            IconURL = "https://duckduckgo.com/favicon.ico";
            Alias = "ddg";
            Description = "DuckDuckGo Search";
          }
        ];
        Default = "DuckDuckGo";
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        #"78272b6fa58f4a1abaac99321d503a20@proton.me" = {
        #  installation_mode = "force_installed";
        #  install_url = "https://addons.mozilla.org/firefox/downloads/latest/proton-pass/latest.xpi";
        #};
      };

      DisableTelemetry = true;
      DisableAccounts = true;
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      TranslateEnabled = false;

      UserMessaging = {
        WhatsNew = false;
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
      };

      FirefoxHome = {
        Search = false;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Stories = false;
        SponsoredStories = false;
        Locked = true;
      };
    };
  };
};
```
