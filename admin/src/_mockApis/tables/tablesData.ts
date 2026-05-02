
import type { basicTable1 } from '@/types/components/table/shadcntable'

import img1 from '@/assets/images/profile/user-1.jpg';
import img2 from '@/assets/images/profile/user-8.jpg';
import img3 from '@/assets//images/profile/user-3.jpg';
import img5 from '@/assets//images/profile/user-5.jpg';
import img7 from '@/assets//images/profile/user-7.jpg';


//Shadcn BASIC table
/*Basic Table 1*/
const basicTableData1: basicTable1[] = [
    {
        avatar: img1,
        name: 'Sunil Joshi',
        post: 'Web Designer',
        pname: 'Elite Admin',
        status: 'Active',
        statuscolor: 'success',
        teams: [
            {
                id: '1',
                color: 'destructive',
                text: 'S'
            },
            {
                id: '2',
                color: 'secondary   ',
                text: 'D'
            }
        ],
        budget: '$3.9'
    },
    {
        avatar: img2,
        name: 'Andrew McDownland',
        post: 'Project Manager',
        pname: 'Real Homes WP Template',
        status: 'Pending',
        statuscolor: 'warning',
        teams: [
            {
                id: '1',
                color: 'secondary',
                text: 'N'
            },
            {
                id: '2',
                color: 'warning   ',
                text: 'X'
            },
            {
                id: '3',
                color: 'primary   ',
                text: 'A'
            }
        ],
        budget: '$24.5k'
    },
    {
        avatar: img3,
        name: 'Christopher Jamil',
        post: 'Project Manager',
        pname: 'MedicalPro WP Template',
        status: 'Completed',
        statuscolor: 'primary',
        teams: [
            {
                id: '1',
                color: 'secondary',
                text: 'X'
            }
        ],
        budget: '$12.8k'
    },
    {
        avatar: img7,
        name: 'Nirav Joshi',
        post: 'Frontend Engineer',
        pname: 'Hosting Press HTML',
        status: 'Active',
        statuscolor: 'success',
        teams: [
            {
                id: '1',
                color: 'primary',
                text: 'X'
            },
            {
                id: '2',
                color: 'destructive',
                text: 'Y'
            }
        ],
        budget: '$2.4k'
    },
    {
        avatar: img5,
        name: 'Micheal Doe',
        post: 'Content Writer',
        pname: 'Helping Hands WP Template',
        status: 'Cancel',
        statuscolor: 'destructive',
        teams: [
            {
                id: '1',
                color: 'secondary',
                text: 'S'
            }
        ],
        budget: '$9.3k'
    }
];







export { basicTableData1 };
