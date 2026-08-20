# Bean Analytics

Bean detail pages include the first drill-down analytics slice for a single bag or lot.

## Included Now

- Brew count for the bean.
- Total bean-in weight consumed through brews.
- Current remaining percentage from `remaining_grams / bag_size_grams`.
- Lifecycle-aware open age from `opened_on`.
- Average rating, channeling rate, the number of channeled brews, and live workspace comparison badges for both metrics.
- Best-rated brews linked back to brew details.
- Recent brews with grind setting, total time, and beverage yield.
- Taste-balance distribution.
- Retention-marker distribution.
- Optional date range filters for brew-derived analytics.

## Data Rules

- Analytics are scoped through the active workspace because `BeansController#set_bean` loads the bean from `current_workspace`.
- `BeanStatistics` owns aggregation logic. Keep the controller and view thin.
- The service uses live Active Record data; do not add summary tables until data volume requires them.
- Brew links must go to private brew detail pages, not public share URLs.
- Remaining percentage reflects the current bean inventory, including brew inventory deductions.
- The bean list shows each bean's primary photo, derived bag status, and remaining amount as `remaining of bag size`; channeling stays on the bean detail analytics card through `BeanStatistics`.
- Date range filters are inclusive and apply only to brew-derived bean analytics: brew count, consumed grams, averages, channeling, distributions, best brews, and recent brews.
- Current bag facts stay unfiltered: remaining percentage and open age always reflect the bag as it is now.
- Open bags count through today. Finished and archived bags stop on their respective lifecycle dates. Used-up bags stop on their latest brew date, falling back to today only when no brew exists. Stock bags have no open duration, and negative durations clamp to zero.
- Average Rating and Channeling cards render live workspace comparison badges below their values using the same badge contract as public bean pages: `TOP N OF C BEANS`, gold/silver/bronze icon treatments for ranks 1–3, and a neutral text-only treatment for rank 4 and later.
- Comparisons include every non-deleted bean in the workspace with usable data for the metric, regardless of lifecycle or publication state. A badge requires at least two eligible beans. Average ratings rank on the displayed one-decimal precision with higher values better; channeling ranks on the displayed integer percentage with lower values better. Display-value ties use competition ranking, and the badge reveals only the current bean's rank and eligible count.

## Deferred

- Interactive ECharts trend lines.
- Photo and note timelines.
- Recipe-profile links from bean analytics.
