export interface menu {
  header?: string;
  title?: string;
  icon?: any;
  to?: string;
  chip?: string;
  chipBgColor?: string;
  chipColor?: string;
  chipVariant?: string;
  chipIcon?: string;
  children?: menu[];
  disabled?: boolean;
  type?: string;
  subCaption?: string;
  isPro?: boolean
}

const sidebarItem: menu[] = [
  { header: "Home" },
  {
    title: "Modern",
    icon: "home-smile-linear",
    to: "/",
    isPro: false,
  },
  {
    title: "Commissions",
    icon: "wallet-money-linear",
    to: "/supervision/commissions",
    isPro: false,
  },


  { header: "PAGES" },
  {
    title: "Tables",
    icon: "tablet-linear",
    to: "#",

    children: [
      {
        title: 'Basic Table',
        to: '/shadcn-table/basic',
        isPro: false,
      },
      {
        title: 'Hover Table',
        to: '/shadcn-table/hover',
        isPro: false,
      },

    ]

  },
  {
    title: 'Form',
    icon: 'document-add-linear',
    to: '/utilities/form',
    isPro: false,

  }, {
    title: 'User Profile',
    icon: 'user-circle-linear',
    to: '/user-profile',
    isPro: false,

  },
  { header: "Apps" },
  {
    title: 'Notes',
    icon: 'notes-linear',
    to: '/apps/notes',
    isPro: false,
  },
  {
    title: 'Tickets',
    icon: 'ticker-star-linear',
    to: '/apps/tickets',
    isPro: false,
  },
  {
    title: 'Blog',
    icon: 'sort-by-alphabet-linear',
    to: '/',
    children: [
      {
        title: 'Blog Posts',
        to: '/apps/blog/post',
        isPro: false,
      },
      {
        title: 'Blog Details',
        to: '/apps/blog/early-black-friday-amazon-deals-cheap-tvs-headphones',
        isPro: false,
      }
    ]
  },

  { header: 'UI ELEMENTS' },
  {
    title: 'Shadcn',
    icon: 'slash-square-linear',
    to: '/',
    children: [
      {
        title: 'Avatar',
        to: 'https://vuejs.tailwind-admin.com/components/ui/avatar',
        isPro: false,
      },
      {
        title: 'Alert',
        to: 'https://vuejs.tailwind-admin.com/components/ui/alert',
        isPro: false,
      },
      {
        title: 'Badge',
        to: 'https://vuejs.tailwind-admin.com/components/ui/badge',
        isPro: false,
      },
      {
        title: 'Breadcrumb',
        to: 'https://vuejs.tailwind-admin.com/components/ui/breadcrumb',
        isPro: false,
      },
      {
        title: 'Carousel',
        to: 'https://vuejs.tailwind-admin.com/components/ui/carousel',
        isPro: false,
      },
      {
        title: 'Card',
        to: 'https://vuejs.tailwind-admin.com/components/ui/card',
        isPro: false,
      },
      {
        title: 'Dropdown',
        to: 'https://vuejs.tailwind-admin.com/components/ui/dropdown',
        isPro: false,
      },

      {
        title: 'Dialog',
        to: 'https://vuejs.tailwind-admin.com/components/ui/dialog',
        isPro: false,
      },
      {
        title: 'Date Picker',
        to: 'https://vuejs.tailwind-admin.com/components/ui/datepicker',
        isPro: false,
      },

      {
        title: 'Skeleton',
        to: 'https://vuejs.tailwind-admin.com/components/ui/skeleton',
        isPro: false,
      },
      {
        title: 'Tabs',
        to: 'https://vuejs.tailwind-admin.com/components/ui/tabs',
        isPro: false,
      },
      {
        title: 'Tooltip',
        to: 'https://vuejs.tailwind-admin.com/components/ui/tooltip',
        isPro: false,
      },
    ]
  },

  { header: 'FORM ELEMENTS' },
  {
    title: 'Shadcn Forms',
    icon: 'banknote-2-linear',
    to: '/',
    children: [
      {
        title: 'Button',
        to: 'https://vuejs.tailwind-admin.com/components/ui/button',
        isPro: false,
      },
      {
        title: 'Input',
        to: 'https://vuejs.tailwind-admin.com/components/form/input',
        isPro: false,
      },
      {
        title: 'Select',
        to: 'https://vuejs.tailwind-admin.com/components/form/select',
        isPro: false,
      },
      {
        title: 'Checkbox',
        to: 'https://vuejs.tailwind-admin.com/components/form/checkbox',
        isPro: false,
      },
      {
        title: 'Radio',
        to: 'https://vuejs.tailwind-admin.com/components/form/radiogroup',
        isPro: false,
      },
      {
        title: 'Combobox',
        to: 'http://vuejs.tailwind-admin.com/components/form/combobox',
        isPro: false,
      },
      {
        title: 'Command',
        to: 'https://vuejs.tailwind-admin.com/components/form/command',
        isPro: false,
      },
    ]
  },

  { header: "Widgets" },
  {
    title: 'Cards',
    icon: 'card-linear',
    to: '/',
    children: [
      {
        title: 'TopCards',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#topCards',
        isPro: false,
      },
      {
        title: 'SocialCards',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#socialcards',
        isPro: false,
      },
      {
        title: 'Best Selling Product',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#bestsellingproduct',
        isPro: false,
      },
      {
        title: 'Payment Gateway',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#paymentgateway',
        isPro: false,
      },
      {
        title: 'Recent Transaction',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#recenttransactioncard',
        isPro: false,
      },
      {
        title: 'Follow Artists',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#followartistscard',
        isPro: false,
      },
      {
        title: 'My Friends ',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#myfriendscard',
        isPro: false,
      },
      {
        title: 'Favourite Artists ',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#favouriteartistscard',
        isPro: false,
      },
      {
        title: 'Upcoming Activity ',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/cards#upcomingactivitycard',
        isPro: false,
      },
    ]
  },

  {
    title: 'Banners',
    icon: 'object-scan-linear',
    to: '/',
    children: [
      {
        title: 'Download Banner ',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/banners#downloadbanner',
        isPro: false,
      },
      {
        title: 'Empty Banner',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/banners#emptybanner',
        isPro: false,
      },
      {
        title: 'Error Banner',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/banners#errorbanner',
        isPro: false,
      },
      {
        title: 'Mutual Friend Banner',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/banners#mutualfriendsbanner',
        isPro: false,
      },
      {
        title: 'Notification Banner',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/banners#notificationsbanner',
        isPro: false,
      },
      {
        title: 'Welcome Banner',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/banners#welcomebanner1',
        isPro: false,
      },

    ]
  },

  {
    title: 'Charts',
    icon: 'pie-chart-2-linear',
    to: '/',
    children: [
      {
        title: 'Revenue Updates',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#revenueupdateschart',
        isPro: false,
      },
      {
        title: 'Yearly Breakup',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#yearlybreakupchart',
        isPro: false,
      },
      {
        title: 'Monthly Earning',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#monthlyearning',
        isPro: false,
      },
      {
        title: 'Employee Salary',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#yearlysaleschart',
        isPro: false,
      },
      {
        title: 'Customers Chart',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#customerschart',
        isPro: false,
      },
      {
        title: 'Projects Chart',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#projectschart',
        isPro: false,
      },
      {
        title: 'Weekly Stats',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#weeklystatschart',
        isPro: false,
      },
      {
        title: 'Expense Chart',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#expancechart',
        isPro: false,
      },
      {
        title: 'Sales Chart',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#salesoverviewchart',
        isPro: false,
      },
      {
        title: 'Sales Growth Chart',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#salesgrowthchart',
        isPro: false,
      },
      {
        title: 'Incremented Sales',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#incrementedsaleschart',
        isPro: false,
      },
      {
        title: 'Use Activity',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#useactivitychart',
        isPro: false,
      },
      {
        title: 'Segmentation',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#customersegmentationchart',
        isPro: false,
      },
      {
        title: 'Monthly Earning',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#monthlyearningecomchart',
        isPro: false,
      },
      {
        title: 'Quarterly Status',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#quarterlystatuschart',
        isPro: false,
      },
      {
        title: 'Weekly Sales',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#weeklysaleschart',
        isPro: false,
      },
      {
        title: 'Total Assets',
        to: 'https://vuejs.tailwind-admin.com/ui-blocks/charts#totalassetschart',
        isPro: false,
      },

    ]
  },

  { header: "Icons" },
  {
    title: 'Iconify Icons',
    to: '/icons/solar',
    isPro: false,
    icon: "structure-linear",
  },






  { header: 'Auth' },
  {
    title: 'Login',
    icon: 'login-2-linear',
    to: '#',

    children: [
      {
        title: 'Boxed Login',
        to: '/auth/login2',
        isPro: false,
      }
    ]
  },
  {
    title: 'Register',
    icon: 'user-plus-rounded-linear',
    to: '#',
    isPro: true,
    children: [
      {
        title: 'Boxed Register',
        to: '/auth/register2',
        isPro: false,
      }
    ]
  },

  { header: "Home" },
  {
    title: "eCommerce",
    icon: "bag-5-linear",
    to: "https://vuejs.tailwind-admin.com/dashboards/eCommerce",
    isPro: true,
  },
  {
    title: "Music",
    icon: "music-note-linear",
    to: "https://vuejs.tailwind-admin.com/dashboards/music",
    isPro: true,
  },

  {
    title: 'General',
    icon: 'chart-linear',
    to: 'https://vuejs.tailwind-admin.com/dashboards/general',
    isPro: true,
  },
  {
    title: 'Front Pages',
    icon: 'document-linear',
    children: [
      {

        title: 'Homepage',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/homepage',
        isPro: true,
      },
      {

        title: 'About Us',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/about',
        isPro: true,
      },
      {

        title: 'Blog',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/blog/post',
        isPro: true,
      },
      {

        title: 'Blog Details',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/blog/early-black-friday-amazon-deals-cheap-tvs-headphones',
        isPro: true,
      },

      {

        title: 'Portfolio',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/portfolio',
        isPro: true,
      },
      {

        title: 'Pricing',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/pricing',
        isPro: true,
      },
      {

        title: 'Contact Us',
        to: 'https://vuejs.tailwind-admin.com/frontend-pages/contact',
        isPro: true,
      },
    ],
  },



  { header: "Apps" },

  {
    title: 'AI',
    icon: 'star-circle-linear',
    children: [

      {
        title: 'Chat',
        to: 'https://vuejs.tailwind-admin.com/apps/ai/chat-ai',
        isPro: true,
      },
      {
        title: 'Image ',
        to: 'https://vuejs.tailwind-admin.com/apps/ai/image-generator',
        isPro: true,
      },
    ]
  },

  {
    title: "User Profile",

    icon: "user-circle-linear",
    children: [
      {
        title: "Profile",
        to: "https://vuejs.tailwind-admin.com/apps/user-profile/profile",
        isPro: true,
      },
      {

        title: "Followers",
        to: "https://vuejs.tailwind-admin.com/apps/user-profile/followers",
        isPro: true,
      },
      {

        title: "Friends",
        to: "https://vuejs.tailwind-admin.com/apps/user-profile/friends",
        isPro: true,
      },
      {

        title: "Gallery",
        to: "https://vuejs.tailwind-admin.com/apps/user-profile/gallery",
        isPro: true,
      },
    ],
  },
  {
    title: 'Invoice',
    icon: 'bill-check-outline',
    to: '/',
    children: [
      {
        title: 'List',
        to: 'https://vuejs.tailwind-admin.com/apps/invoice',
        isPro: true,
      },
      {
        title: 'Details',
        to: 'https://vuejs.tailwind-admin.com/apps/invoice/details/102',
        isPro: true,
      },
      {
        title: 'Create',
        to: 'https://vuejs.tailwind-admin.com/apps/invoice/create',
        isPro: true,
      },
      {
        title: 'Edit',
        to: 'https://vuejs.tailwind-admin.com/apps/invoice/edit/102',
        isPro: true,
      }
    ]
  },
  {
    title: "Ecommerce",
    icon: "cart-large-2-linear",
    children: [
      {

        title: "Shop",
        to: "https://vuejs.tailwind-admin.com/apps/ecommerce/shop",
        isPro: true,
      },
      {

        title: "Details",
        to: "https://vuejs.tailwind-admin.com/apps/ecommerce/detail/3",
        isPro: true,
      },
      {

        title: "List",
        to: "https://vuejs.tailwind-admin.com/apps/ecommerce/list",
        isPro: true,
      },
      {

        title: "Checkout",
        to: "https://vuejs.tailwind-admin.com/apps/ecommerce/checkout",
        isPro: true,
      },
      {

        title: "Add Product",
        to: "https://vuejs.tailwind-admin.com/apps/ecommerce/addproduct",
        isPro: true,
      },
      {

        title: "Edit Product",
        to: "https://vuejs.tailwind-admin.com/apps/ecommerce/editproduct",
        isPro: true,
      },
    ],
  },
  {
    title: 'Chats',
    icon: 'dialog-linear',
    to: 'https://vuejs.tailwind-admin.com/apps/chats',
    isPro: true,
  },
  {
    title: 'Kanban',
    icon: 'dialog-linear',
    to: 'https://vuejs.tailwind-admin.com/apps/kanban',
    isPro: true,
  },

  {
    title: 'Calendar',
    icon: 'calendar-linear',
    to: 'https://vuejs.tailwind-admin.com/apps/calendar',
    isPro: true,
  },
  {
    title: 'Contacts',
    icon: 'users-group-rounded-linear',
    to: 'https://vuejs.tailwind-admin.com/apps/contacts',
    isPro: true,
  },

  {
    title: 'Email',
    icon: 'letter-linear',
    to: 'https://vuejs.tailwind-admin.com/apps/email',
    isPro: true,
  },

  {
    title: 'Customers',
    icon: 'user-circle-outline',
    to: 'https://vuejs.tailwind-admin.com/table/user-table',
    isPro: true,
  },

  {
    title: 'Orders',
    icon: 'clapperboard-edit-linear',
    to: 'https://vuejs.tailwind-admin.com/table/orders-table',
    isPro: true,
  },

  { header: "UI ELEMENTS" },
  {
    title: "Animated Comp",
    icon: "reel-linear",
    children: [
      {
        title: "Button",
        to: "https://vuejs.tailwind-admin.com/animated-components/buttons",
        isPro: true,
      },
      {
        title: "Card",
        to: "https://vuejs.tailwind-admin.com/animated-components/card",
        isPro: true,
      },
      {
        title: "Text",
        to: "https://vuejs.tailwind-admin.com/animated-components/text",
        isPro: true,
      },
      {
        title: "Table",
        to: "https://vuejs.tailwind-admin.com/animated-components/table",
        isPro: true,
      },
      {
        title: "Tooltip",
        to: "https://vuejs.tailwind-admin.com/animated-components/tooltip",
        isPro: true,
      },
      {
        title: "List",
        to: "https://vuejs.tailwind-admin.com/animated-components/list",
        isPro: true,
      },
      {
        title: "Link",
        to: "https://vuejs.tailwind-admin.com/animated-components/link",
        isPro: true,
      },
      {
        title: "Slider",
        to: "https://vuejs.tailwind-admin.com/animated-components/slider",
        isPro: true,
      },
      {
        title: "Forms",
        to: "https://vuejs.tailwind-admin.com/animated-components/forms",
        isPro: true,
      },
    ]
  },

  { header: "FORM ELEMENTS" },

  {
    title: "Form layouts",
    icon: "documents-linear",
    children: [
      {
        title: "Form layouts",
        to: "https://vuejs.tailwind-admin.com/forms/form-layouts",
        isPro: true,
      },
      {
        title: "Form Horizontal",
        to: "https://vuejs.tailwind-admin.com/forms/form-horizontal",
        isPro: true,
      },
      {
        title: "Form Vertical",
        to: "https://vuejs.tailwind-admin.com/forms/form-vertical",
        isPro: true,
      },
      {
        title: "Form Validation",
        to: "https://vuejs.tailwind-admin.com/forms/form-validation",
        isPro: true,
      },
    ]
  },

  { header: "Tables" },
  {
    title: "Shadcn Tables",
    icon: "tablet-linear",
    to: "#",

    children: [
      {
        title: 'Editable Table',
        to: 'https://vuejs.tailwind-admin.com/shadcn-tables/edit',
        isPro: true,
      }
    ]

  },
  {
    title: "Data Tables",
    icon: "bedside-table-3-linear",
    to: "#",

    children: [

      {
        title: 'Basic Table',
        to: 'https://vuejs.tailwind-admin.com/table/basic-table',
        isPro: true,
      }, {
        title: 'Column Pining',
        to: 'https://vuejs.tailwind-admin.com/table/column-table',
        isPro: true,
      },
      {
        title: 'Reactive',
        to: 'https://vuejs.tailwind-admin.com/table/reactive-table',
        isPro: true,
      }
    ]

  },


  { header: "Charts" },
  {
    title: "ApexCharts",
    icon: "pie-chart-3-linear",
    children: [
      {
        title: 'Line Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/line',
        isPro: true,
      },
      {
        title: 'Area Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/area',
        isPro: true,
      }, {
        title: 'Gradient Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/gradient',
        isPro: true,
      },
      {
        title: 'Candlestick',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/candlestick',
        isPro: true,
      }, {
        title: 'Column Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/column',
        isPro: true,
      },
      {
        title: 'Doughnut & Pie',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/doughnut',
        isPro: true,
      },
      {
        title: 'Radial & Radar',
        to: 'https://vuejs.tailwind-admin.com/charts/apex-charts/radialbar',
        isPro: true,
      },

    ]

  },



  {
    title: "Shadcn Charts",
    icon: "chart-2-linear",
    to: "#",
    children: [
      {
        title: 'Line Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/shadcn/linechart',
        isPro: true,
      },
      {
        title: 'Area Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/shadcn/areachart',
        isPro: true,
      },
      {
        title: 'Bar Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/shadcn/barchart',
        isPro: true,
      },
      {
        title: 'Pie Chart',
        to: 'https://vuejs.tailwind-admin.com/charts/shadcn/piechart',
        isPro: true,
      },
    ]
  },


  { header: "Pro Pages" },
  {
    title: 'Account Setting',
    icon: 'settings-minimalistic-linear',
    to: 'https://vuejs.tailwind-admin.com/theme-pages/account-settings',
    isPro: true,
  },
  {
    title: 'FAQ',
    icon: 'question-circle-linear',
    to: 'https://vuejs.tailwind-admin.com/theme-pages/faq',
    isPro: true,
  },
  {
    title: 'Pricing',
    icon: 'tag-price-linear',
    to: 'https://vuejs.tailwind-admin.com/theme-pages/pricing',
    isPro: true,
  },
  {
    title: 'Rollbase Access',
    icon: 'accessibility-linear',
    to: 'https://vuejs.tailwind-admin.com/theme-pages/casl',
    isPro: true,
  },
  {
    title: 'Landingpage',
    icon: 'three-squares-linear',
    to: 'https://vuejs.tailwind-admin.com/landingpage',
    isPro: true,
  },
  {
    title: 'Integrations',
    icon: 'home-add-linear',
    to: 'https://vuejs.tailwind-admin.com/theme-pages/integration',
    isPro: true,
  },
  {
    title: 'API Keys',
    icon: 'key-linear',
    to: 'https://vuejs.tailwind-admin.com/theme-pages/apikey',
    isPro: true,
  },

  { header: 'Auth' },
  {
    title: 'Login',
    icon: 'login-2-linear',
    to: '#',

    children: [
      {
        title: 'Side Login',
        to: 'https://vuejs.tailwind-admin.com/auth/auth1/login',
        isPro: true,
      },
    ]
  },

  {
    title: 'Register',
    icon: 'user-plus-rounded-linear',
    to: '#',
    isPro: true,
    children: [
      {
        title: 'Side Register',
        to: 'https://vuejs.tailwind-admin.com/auth/auth1/register',
        isPro: true,
      },
    ]
  },

  {
    title: 'Forgot Password',
    icon: 'password-linear',
    to: '#',

    children: [
      {
        title: 'Side Forgot',
        to: 'https://vuejs.tailwind-admin.com/auth/auth1/forgot-password',
        isPro: true,
      },
      {
        title: 'Boxed Forgot',
        to: 'https://vuejs.tailwind-admin.com/auth/forgot-password2',
        isPro: true,
      }
    ]
  },

  {
    title: 'Two Steps',
    icon: 'shield-keyhole-minimalistic-linear',
    to: '#',

    children: [
      {
        title: 'Side Two Steps',
        to: 'https://vuejs.tailwind-admin.com/auth/auth1/two-steps',
        isPro: true,
      },
      {
        title: 'Boxed 2 Steps',
        to: 'https://vuejs.tailwind-admin.com/auth/two-step2',
        isPro: true,
      }
    ]
  },
  {
    title: 'Error',
    icon: 'link-broken-minimalistic-linear',
    to: 'https://vuejs.tailwind-admin.com/auth/error',
    isPro: true,
  },
  {
    title: 'Maintenance',
    icon: 'settings-linear',
    to: 'https://vuejs.tailwind-admin.com/auth/maintenance',
    isPro: true,
  },

  { header: "Other" },
  {
    title: "Disabled",
    icon: "forbidden-circle-linear",
    disabled: true,
    to: "#",
    isPro: false,
  },
  {
    title: "Sub Caption",
    icon: "star-fall-minimalistic-2-linear",
    subCaption: "This is the subtitle",
    to: "#",
    isPro: false,
  },
  {
    title: "Chip",
    icon: "shield-check-linear",
    chip: "9",
    chipColor: "surface",
    chipBgColor: "primary",
    to: "#",
    isPro: false,
  },
  {
    title: "Outlined",
    icon: "smile-circle-linear",
    chip: "outline",
    chipColor: "primary",
    chipVariant: "outline",
    to: "#",
    isPro: false,
  },
  {
    title: "External Link",
    icon: "link-broken-minimalistic-linear",
    to: "https://google.com",
    type: "external",
    isPro: false,
  },
];

export default sidebarItem;
