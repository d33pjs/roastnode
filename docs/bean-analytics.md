# Bean Analytics

Bean detail pages include the first drill-down analytics slice for a single bag or lot.

## Included Now

- Brew count for the bean.
- Total bean-in weight consumed through brews.
- Current remaining percentage from `remaining_grams / bag_size_grams`.
- Open age from `opened_on`.
- Average rating, channeling rate, and the number of channeled brews.
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

## Deferred

- Interactive ECharts trend lines.
- Photo and note timelines.
- Recipe links, because recipes are deferred.
- Cross-bean comparison from the bean detail page.
