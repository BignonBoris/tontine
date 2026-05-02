const ModuleRoutes = [
    {
        path: '/auth/login',
        component: () => import('../views/modules/auth/login.vue'),
    },
    {
        path: '/modules',
        component: () => import('../views/modules/index.vue'),
    },
];

export default ModuleRoutes;