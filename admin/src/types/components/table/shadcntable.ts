
/*Basic table 1 types*/
type teamGroupType={
    id: string;
    color: string;
    text: string;
}
type basicTable1 = {
    avatar: string;
    name: string;
    post: string;
    pname: string;
    status: string;
    statuscolor: string;
    teams: teamGroupType[];
    budget: string;
};



export type { basicTable1};