# Roastnode Context

Roastnode tracks private household coffee practice. The language in this glossary keeps daily logging, recipe targets, equipment, and coffee inventory distinct.

## Language

**Brew**:
A single prepared coffee drink or batch logged by a workspace member. A brew belongs to one **Brew method**.
_Avoid_: Shot as the general term, extraction as the general term

**External Coffee**:
A purchased or otherwise household-external coffee drink logged by a workspace member for memory, comparison, and sharing. It is workspace-private by default, is not a **Brew**, and does not consume workspace bean inventory or require household equipment.
_Avoid_: Cafe brew, out-of-home brew, third brew method

**Drink Type**:
The menu-style name of an **External Coffee**, such as latte macchiato, americano, flat white, black coffee, or matcha latte. It may include adjacent cafe drinks and is searchable suggestion text, not a **Brew method**.
_Avoid_: Brew method for external coffee, fixed variant enum, recipe

**Drink Size**:
The optional cafe/menu size of an **External Coffee**, captured as free text such as small, medium, grande, 250ml, or single. It helps compare price and experience without normalizing every shop's size system.
_Avoid_: Universal cup size, required serving volume

**External Coffee Place**:
The free-text place name and optional place location where an **External Coffee** was bought or consumed. It is not a reusable coffee-shop directory record.
_Avoid_: Cafe account, shop entity, roaster

**External Coffee Location Capture**:
An explicit per-entry action where a member chooses to attach current device coordinates to an **External Coffee**. It is optional and is never automatic background location tracking.
_Avoid_: Always-on location, passive location history, required coordinates

**External Coffee Taste**:
The sensory assessment of an **External Coffee** across two simple axes: acidity-to-bitterness and weak-to-strong. It is separate from espresso and Quick Drip taste labels because bought drinks may be diluted, milk-based, or non-espresso.
_Avoid_: Reusing espresso taste balance as the only external taste field

**External Coffee Photo**:
An optional private photo attached to an **External Coffee**, such as the cup, menu, venue, or drink presentation. Public use requires explicit selection through a public share.
_Avoid_: Public-by-default cafe photo, raw media URL

**External Coffee Share**:
An explicit public snapshot of one **External Coffee**. It controls whether date, time, place name, and location are public for that share.
_Avoid_: Public-by-default external log, global cafe privacy setting

**External Coffee Link**:
An optional public or private link attached to an **External Coffee**, such as a cafe website, menu, product page, or related post. Only public links may appear in an **External Coffee Share**.
_Avoid_: Public by default link, embedded private source

**External Coffee Comparison**:
Comparison of **External Coffees** by drink type, place, price, rating, and external taste axes. It may be compared with household brews only at broad rating/taste levels, not through bean inventory or equipment metrics.
_Avoid_: Bean analytics, equipment analytics, extraction comparison

**Brew method**:
The preparation category of a **Brew**, such as espresso or Quick Drip. A brew method describes how coffee is prepared, not the specific equipment record used.
_Avoid_: Recipe, machine, personal workflow

**Filter coffee**:
A broader family of brew methods where water passes through ground coffee and a filter into a serving vessel or cup. It is useful background language, but not the first visible logging method.
_Avoid_: Filterkaffee, drip as the broad category

**Quick Drip**:
A first-class brew method for an automatic machine-style filter brew where ground coffee, a filter, and Machine cups produce a pot or thermos batch. Ground coffee amount may be unmeasured.
_Avoid_: My filter coffee, personal filter, professional filter coffee

**Machine cups**:
The brewer-specific cup scale used to choose the water amount for a Quick Drip brew. Machine cups are not assumed to equal a universal cup volume.
_Avoid_: Output cups, servings, universal cups

**Output amount**:
The optional measured or estimated finished coffee amount for a brew. Quick Drip does not require Output amount because Machine cups are the normal water selector.
_Avoid_: Required yield

**Brew duration**:
The optional total elapsed time for a brew. Quick Drip may record Brew duration, but does not use espresso-specific timing concepts such as preinfusion or first drip.
_Avoid_: Preinfusion for Quick Drip, first drip for Quick Drip

**Ground coffee amount**:
The optional weighed amount of coffee used for a Quick Drip brew. It is not required because some Quick Drip workflows use spoons rather than a scale.
_Avoid_: Required dose, bean in

**Coffee spoons**:
The household/user-counted spoon measure used for unweighed Quick Drip coffee. Coffee spoons support estimated inventory deduction when no Ground coffee amount is entered.
_Avoid_: Exact dose, measured grams

**Grams per coffee spoon**:
A per-user preference estimating how many grams one of that user's coffee spoons contains. Quick Drip uses it with Coffee spoons to estimate inventory consumption.
_Avoid_: Universal spoon size, machine cup size

**Typical spoon fallback**:
The app's default 5g-per-spoon estimate used when a user has not calibrated Grams per coffee spoon.
_Avoid_: Exact spoon calibration, required user setting

**Coffee amount source**:
Whether a brew's consumed coffee grams came from a measured Ground coffee amount or from a Coffee spoons estimate. Measured grams win when both measured grams and spoons are present.
_Avoid_: Inventory reason, adjustment type

**Brewer**:
The equipment used to make a non-espresso brew. For Quick Drip, the brewer is required because its cup scale defines the brew's water amount.
_Avoid_: Machine as the Quick Drip UI label

**Machine**:
The equipment used to make espresso. A Machine is separate from a Brewer because the two are not interchangeable in logging.
_Avoid_: Brewer for espresso equipment, generic equipment when method matters

**Pre-ground brew**:
A brew logged without a grinder because the coffee was already ground before the household workflow began.
_Avoid_: Missing grinder, invalid grinder

**Bean grind state**:
Whether a bean bag is whole bean or pre-ground. Existing bags are whole bean by default unless explicitly changed.
_Avoid_: Bean type, roast type

**Enabled brew method**:
A per-user preference that controls which brew method tabs appear on the Log screen. It does not hide historical brews, shared household activity, or existing records for disabled methods.
_Avoid_: Workspace method, authorization rule

**Log screen**:
The single brew-logging entry point that shows a user's enabled brew methods as stable tabs. It opens the user's last logged enabled method by default without reordering the tabs.
_Avoid_: Log espresso as the general entry point, moving method tabs

**External Coffee Log Tab**:
The default Log screen entry point for creating an **External Coffee**. It sits beside brew-method tabs in the UI but is not itself a **Brew method**.
_Avoid_: External brew method, hidden separate app area

**External Coffee Hero Card**:
The screenshot-worthy card for an **External Coffee**. It is photo-forward when a primary photo exists and otherwise presents drink type, place, price, rating, and external taste axes without espresso graphs, inventory metrics, or household equipment.
_Avoid_: Espresso chart card, gear card, text-only receipt

**Quick Drip Hero Card**:
The method-specific Hero Brew Card variant for Quick Drip. It stays in the existing dense card family and uses a metric-first batch summary instead of an espresso extraction chart.
_Avoid_: Separate Quick Drip app card, decorative process illustration

**Quick Drip taste**:
The method-specific taste language for Quick Drip brews. Quick Drip uses three choices: Weak, Balanced, and Harsh.
_Avoid_: Espresso sour-neutral-bitter labels on Quick Drip

## Example Dialogue

Dev: "Should I add Filterkaffee as a new machine?"

Domain expert: "No. Add filter coffee as the brew method. The machine is only the brewer used for one brew."

Dev: "Then is the household's fast machine process its own brew method?"

Domain expert: "Yes. It is Quick Drip, optimized for fast logging."

Dev: "Should Machine cups be optional?"

Domain expert: "No. For Quick Drip, Machine cups are the required water selector."

Dev: "Should Quick Drip require Output amount?"

Domain expert: "No. Output amount is optional; Machine cups carry the normal water measure."

Dev: "Does Quick Drip need espresso timing fields?"

Domain expert: "No. Quick Drip can have optional Brew duration, but no preinfusion, first drip, or channeling."

Dev: "Should Quick Drip require Ground coffee amount?"

Domain expert: "No. Quick Drip can be logged from Machine cups when coffee is added by spoon."

Dev: "Should unweighed Quick Drip skip inventory?"

Domain expert: "No. Use Coffee spoons to estimate inventory so remaining coffee stays roughly useful."

Dev: "How does a spoon-based Quick Drip consume inventory?"

Domain expert: "Multiply the brew's Coffee spoons by the user's Grams per coffee spoon."

Dev: "What if a Quick Drip brew has both Ground coffee amount and Coffee spoons?"

Domain expert: "Ground coffee amount wins for inventory because measured grams are more accurate than spoon estimates."

Dev: "How do we know whether consumed grams were measured or estimated?"

Domain expert: "Use Coffee amount source on the brew."

Dev: "What if the user has not set Grams per coffee spoon?"

Domain expert: "Use the Typical spoon fallback so Quick Drip inventory still works immediately."

Dev: "Should Log tabs reorder based on the last brew?"

Domain expert: "No. Keep the tabs stable, but open the last logged enabled method."

Dev: "Should External Coffee live away from the Log screen?"

Domain expert: "No. Use an External Coffee Log Tab so bought drinks are logged from the same starting point without becoming a Brew method."

Dev: "Should an External Coffee card use espresso-style extraction visuals?"

Domain expert: "No. Use an External Coffee Hero Card that can make the drink photo the primary visual and keeps cafe-specific facts prominent."

Dev: "Should the Quick Drip card look unrelated to espresso cards?"

Domain expert: "No. Keep the same Hero Brew Card family, but show Quick Drip batch metrics instead of espresso extraction metrics."

Dev: "Should a Starbucks latte be logged as a Brew without a household bean?"

Domain expert: "No. Log it as External Coffee because it happened outside the household preparation and inventory workflow."

Dev: "Is an External Coffee visible only to the person who logged it?"

Domain expert: "No. It follows normal workspace privacy like other coffee records; public sharing is explicit."

Dev: "Should External Coffee variants be added as Brew methods?"

Domain expert: "No. Use Drink Type for menu-style names; Brew methods stay for household preparation categories."

Dev: "Should all cafe drink sizes be normalized to one fixed scale?"

Domain expert: "No. Use optional Drink Size text because shop size systems vary and exact volume is usually not known."

Dev: "Should every cafe become a shared CoffeeShop record?"

Domain expert: "No. External Coffee Place is free text first; structured shop records can wait until repeated-place workflows prove they are needed."

Dev: "Should mobile logging automatically attach the current location?"

Domain expert: "No. Location capture is explicit per External Coffee and logging works without it."

Dev: "Can External Coffee use only the espresso sour-neutral-bitter field?"

Domain expert: "No. External Coffee Taste has a separate strength/body axis because cafe drinks can be weak, strong, diluted, milk-heavy, or harsh."

Dev: "Are cafe photos public once attached?"

Domain expert: "No. External Coffee Photos are private media unless a public share explicitly selects them."

Dev: "Should sharing cafe location be one global account setting?"

Domain expert: "No. External Coffee Share controls date, time, place name, and location visibility per shared record."

Dev: "Can an External Coffee Share show every attached link?"

Domain expert: "No. It can show only External Coffee Links marked public."

Dev: "Should External Coffees count in bean or equipment statistics?"

Domain expert: "No. Use External Coffee Comparison for price, rating, taste, drink type, and place; household brew analytics stay tied to beans and equipment."

Dev: "Does Quick Drip use the espresso taste labels?"

Domain expert: "No. Quick Drip uses Weak, Balanced, and Harsh."

Dev: "Can I log Quick Drip without choosing equipment?"

Domain expert: "No. Quick Drip requires a Brewer because Machine cups are brewer-specific."

Dev: "Can an espresso Machine be selected as a Quick Drip Brewer?"

Domain expert: "No. Machine and Brewer are separate equipment kinds."

Dev: "Does Quick Drip require a grinder?"

Domain expert: "No. A Quick Drip brew can be pre-ground, so its grinder is optional."

Dev: "Is pre-ground only a property of one brew?"

Domain expert: "No. Pre-ground is usually a property of the bean bag, so the bag records its Bean grind state."
