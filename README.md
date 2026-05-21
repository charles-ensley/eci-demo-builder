# ECI Demo Builder

A drop-in Salesforce demo asset that replicates Einstein Conversation Insights (ECI) without requiring actual call recordings, transcription providers, or ECI enablement. Build fully customized Video Call records with transcripts, summaries, generative insights, and actionable recommendations -- all tailored to the story you want to tell.

## What You Get

- **ECI Demo Wizard** -- A multi-step UI where you input customer details, call narrative, and scenario type. The wizard auto-generates transcripts, summaries, insights, and recommendations that you can preview and edit before creating the record.
- **ECI Playback Page** -- A record page component that mirrors the real ECI Video Call experience: 3-column layout with participant sidebar, center video player (supports YouTube, Google Drive, or direct video URLs), and tabbed panels for Transcript, Summary, Generative Insights, and Recommended Actions.
- **Call Explorer** -- A floating chat dialog (launched via the "Explore Conversation" button above the video) that lets users ask questions about the call. Answers are generated from pre-built Q&A pairs and transcript keyword matching -- no AI required, but looks just like the real thing.
- **Recommended Actions** -- AI-style recommendation cards that create real Salesforce records when clicked (Tasks, Opportunities, Events, Contacts, and more).

## Prerequisites

- Salesforce org (scratch, sandbox, or Developer Edition)
- [Salesforce CLI v2](https://developer.salesforce.com/tools/salesforcecli) (`sf` commands)
- Authenticated to your target org (`sf org login web`)

## Quick Deploy

```bash
# Clone the repo
git clone https://github.com/charles-ensley/eci-demo-builder.git
cd eci-demo-builder

# Deploy to your default org
sf project deploy start --target-org <your-org-alias>

# Assign the permission set to your user
sf org assign permset --name ECI_Demo_User --target-org <your-org-alias>
```

## Post-Deploy Setup

1. **Add the Playback component to the record page:**
   - Navigate to a Demo Video Call record
   - Click the gear icon > Edit Page (Lightning App Builder)
   - Drag the `eciDemoPlayback` component onto the record page
   - Remove or minimize the standard record detail section
   - Save and activate the page

2. **Access the Wizard:**
   - Open the **ECI Demo Builder** tab from the App Launcher
   - Follow the 6-step wizard to create your demo call

3. **(Optional) Add to an App:**
   - Edit your Lightning App and add the "Demo Video Calls" and "ECI Demo Builder" tabs

## What's Included

| Component | Type | Description |
|-----------|------|-------------|
| `Demo_Video_Call__c` | Custom Object | Stores call metadata, transcript, insights, and summaries |
| `Call_Recommendation__c` | Custom Object | Stores actionable recommendations linked to a call |
| `EciDemoDataGenerator` | Apex Class | Scenario-based content generation engine |
| `EciDemoController` | Apex Class | Controller for LWC data operations |
| `EciDemoControllerTest` | Apex Test | Full test coverage for the controller |
| `eciDemoPlayback` | LWC | 3-column ECI-style record page component |
| `eciDemoWizard` | LWC | 6-step demo call creation wizard |
| `eciRecommendedActions` | LWC | Recommendation cards with record creation |
| `eciCallExplorer` | LWC | Floating Call Explorer chat dialog |
| `ECI_Demo_User` | Permission Set | Object and field access for demo users |
| `YouTube` | CSP Trusted Site | Enables YouTube video embeds |
| `Google_Drive` | CSP Trusted Site | Enables Google Drive video embeds |

## Supported Video Sources

The playback component auto-detects and embeds videos from:

- **YouTube** -- `youtube.com/watch?v=...` or `youtu.be/...` links
- **Google Drive** -- `drive.google.com/file/d/.../view` links (video must be shared as "Anyone with the link")
- **Direct URLs** -- Any `.mp4` or `.webm` file URL
- **No video** -- Shows a dark placeholder with play button (still looks realistic)

## Call Explorer

The playback page includes an "Explore Conversation" button above the video player. Clicking it opens a floating chat dialog that mimics ECI's Call Explorer:

- **Suggested questions** -- Pre-generated questions based on the call scenario are displayed as clickable pills
- **Free-text input** -- Users can type their own questions about the call
- **Keyword matching** -- Answers are drawn from scenario-specific Q&A pairs generated during call creation; unmatched questions fall back to transcript excerpt search
- **Typing animation** -- Answers stream in character-by-character for a realistic AI feel
- **"Ask another question"** -- Returns to the suggested questions list so the user can keep exploring

No AI/LLM calls are made -- all answers are generated from the call data at record creation time.

## Built-In Scenarios

The wizard includes pre-built content templates for common demo narratives:

- **Renewal / Upsell** -- Contract renewal discussions with upgrade opportunities
- **New Business** -- First meetings with prospective customers
- **Competitive Displacement** -- Replacing a competitor product
- **Executive Briefing** -- High-level strategic conversations

Each scenario auto-generates a realistic transcript, call summary, generative Q&A insights, and contextual recommendations.

## Customization

All generated content is fully editable in the wizard before record creation. You can:

- Modify transcript entries (speakers, timestamps, text, insight tags)
- Edit summary sections (customer impression, call overview, next steps)
- Adjust generative insight Q&A pairs
- Customize recommendation actions, priorities, and labels

## Using with Cursor

If you're using [Cursor](https://cursor.sh), you can point your agent at this repo for automated deployment:

> Deploy the ECI Demo Builder from https://github.com/charles-ensley/eci-demo-builder to my org

The agent can clone, deploy, assign permissions, and help you configure the record page.

## License

MIT
