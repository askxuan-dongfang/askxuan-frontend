<script setup lang="ts">
import WorkApplication from '../../../../packages/admin-ui/components/WorkApplication.vue'
import {useAuthStore} from '@/stores/auth'
import {useRouter} from 'vue-router'
const auth=useAuthStore(),router=useRouter()
function exit(){auth.logout();router.replace('/login')}
</script><template><WorkApplication :token="auth.token" kind="temple" @exit="exit"/></template>
