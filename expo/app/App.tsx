import { NavigationContainer } from '@react-navigation/native'
import { createNativeStackNavigator } from '@react-navigation/native-stack'
import { StatusBar } from 'expo-status-bar'

import type { RootStackParamList } from './src/navigation'
import { HomeScreen } from './src/screens/HomeScreen'
import { RepoSearchScreen } from './src/screens/RepoSearchScreen'

const Stack = createNativeStackNavigator<RootStackParamList>()

/**
 * The benchmark app, written entirely in React Native: a home screen that
 * hands a keyword to a search screen and takes the results back.
 */
export default function App() {
  return (
    <>
      <StatusBar style="dark" />
      <NavigationContainer>
        <Stack.Navigator>
          <Stack.Screen
            component={HomeScreen}
            name="Home"
            options={{ title: 'Home' }}
          />
          <Stack.Screen
            component={RepoSearchScreen}
            name="RepoSearch"
            options={{ headerShown: false }}
          />
        </Stack.Navigator>
      </NavigationContainer>
    </>
  )
}
